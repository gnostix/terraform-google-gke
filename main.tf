# -----------------------------------------------------------------------------
# Cluster (control plane)
# Resource addresses (".this", ".default", ".nodes") are part of the module's
# contract: renaming them would make consumers destroy/recreate on upgrade.
# -----------------------------------------------------------------------------
resource "google_container_cluster" "this" {
  project  = var.project_id
  name     = var.name
  location = var.location

  # Nodes live in google_container_node_pool.pools; GKE insists on creating
  # a default pool first, so create 1 node and delete it immediately.
  remove_default_node_pool = true
  initial_node_count       = 1

  # Shape of that throw-away default pool (works even if the Compute default
  # SA is disabled). Ignored after creation - see lifecycle below.
  node_config {
    service_account = google_service_account.nodes.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]
    disk_type       = "pd-standard" # cheapest: this node lives for ~2 minutes
    disk_size_gb    = 30
  }

  deletion_protection = var.deletion_protection

  # --- networking: VPC-native ---------------------------------------------------
  network         = var.network_id
  subnetwork      = var.subnet_id
  networking_mode = "VPC_NATIVE"

  ip_allocation_policy {
    cluster_secondary_range_name  = var.pods_range_name
    services_secondary_range_name = var.services_range_name
  }

  # Rendered only for private nodes (provider docs: omit the block otherwise).
  dynamic "private_cluster_config" {
    for_each = var.private_nodes ? [1] : []
    content {
      enable_private_nodes    = true
      enable_private_endpoint = false
    }
  }

  # --- control plane access -----------------------------------------------------
  control_plane_endpoints_config {
    dns_endpoint_config {
      allow_external_traffic = var.dns_endpoint_allow_external
    }
    ip_endpoints_config {
      enabled = true
    }
  }

  # --- identity -------------------------------------------------------------
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  # --- add-ons -----------------------------------------------------------------
  secret_manager_config {
    enabled = var.enable_secret_manager_addon
  }

  # --- operations -------------------------------------------------------------
  release_channel {
    channel = var.release_channel
  }

  logging_config {
    enable_components = var.logging_components
  }

  monitoring_config {
    enable_components = var.monitoring_components
    managed_prometheus {
      enabled = var.managed_prometheus
    }
  }

  lifecycle {
    # node_config only shapes the deleted default pool; the API reports
    # different values afterwards, which would cause permanent diffs.
    ignore_changes = [node_config]
  }

  depends_on = [google_project_iam_member.nodes]
}

# -----------------------------------------------------------------------------
# Node pools - one resource instance per entry in var.node_pools (v2.0.0)
#   module.<call>.google_container_node_pool.pools["default"]
#   module.<call>.google_container_node_pool.pools["batch"]  ...
# -----------------------------------------------------------------------------
resource "google_container_node_pool" "pools" {
  for_each = var.node_pools

  project  = var.project_id
  name     = each.key == "default" ? "${var.name}-pool" : "${var.name}-${each.key}" # "default" keeps the v1 name
  location = var.location
  cluster  = google_container_cluster.this.name

  # Fixed size OR autoscaler (see v1.1.0) - now per pool.
  node_count = each.value.autoscaling == null ? each.value.node_count : null

  dynamic "autoscaling" {
    for_each = each.value.autoscaling == null ? [] : [each.value.autoscaling]
    content {
      min_node_count  = autoscaling.value.min_nodes
      max_node_count  = autoscaling.value.max_nodes
      location_policy = autoscaling.value.location_policy
    }
  }

  management {
    auto_repair  = true # also replaces reclaimed Spot nodes
    auto_upgrade = true # follow the release channel
  }

  node_config {
    machine_type = each.value.machine_type
    spot         = each.value.spot
    disk_type    = each.value.disk_type
    disk_size_gb = each.value.disk_size_gb
    image_type   = "COS_CONTAINERD"

    service_account = google_service_account.nodes.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"] # access limited by IAM, not scopes

    tags   = each.value.network_tags
    labels = merge({ pool = each.key }, each.value.labels) # v1 default label was pool = "default"

    # Taints keep pods off a pool unless they tolerate it, e.g. a Spot batch pool
    # that only batch jobs (with a matching toleration) may use.
    dynamic "taint" {
      for_each = each.value.taints
      content {
        key    = taint.value.key
        value  = taint.value.value
        effect = taint.value.effect
      }
    }

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }
  }
}

# -----------------------------------------------------------------------------
# v1.x -> v2.0.0: the single pool's ADDRESS changed. Without this block,
# Terraform would destroy google_container_node_pool.default and create
# google_container_node_pool.pools["default"] - every consumer would lose
# their nodes on upgrade. `moved` says "same object, new address": state is
# rewritten, nothing in GCP changes.
# Keep moved blocks for at least one major version (consumers may skip versions).
# -----------------------------------------------------------------------------
moved {
  from = google_container_node_pool.default
  to   = google_container_node_pool.pools["default"]
}
