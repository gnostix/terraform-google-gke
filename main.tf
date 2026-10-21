# -----------------------------------------------------------------------------
# Cluster (control plane)
# Resource addresses (".this", ".default", ".nodes") are part of the module's
# contract: renaming them would make consumers destroy/recreate on upgrade.
# -----------------------------------------------------------------------------
resource "google_container_cluster" "this" {
  project  = var.project_id
  name     = var.name
  location = var.location

  # Nodes live in google_container_node_pool.default; GKE insists on creating
  # a default pool first, so create 1 node and delete it immediately.
  remove_default_node_pool = true
  initial_node_count       = 1

  # Shape of that throw-away default pool (works even if the Compute default
  # SA is disabled). Ignored after creation - see lifecycle below.
  node_config {
    service_account = google_service_account.nodes.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]
    disk_type       = var.disk_type
    disk_size_gb    = var.disk_size_gb
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
# Node pool
# -----------------------------------------------------------------------------
resource "google_container_node_pool" "default" {
  project  = var.project_id
  name     = "${var.name}-pool"
  location = var.location
  cluster  = google_container_cluster.this.name

  # Fixed size OR autoscaler - never both. With autoscaling, node_count = null
  # means "not managed by Terraform": the autoscaler owns the number of nodes,
  # so plans don't fight it.
  node_count = var.autoscaling == null ? var.node_count : null

  # Rendered 0 or 1 times - same `dynamic` pattern as private_cluster_config.
  # Adding/removing this block is an in-place update of the pool (no replacement).
  dynamic "autoscaling" {
    for_each = var.autoscaling == null ? [] : [var.autoscaling]
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
    machine_type = var.machine_type
    spot         = var.spot
    disk_type    = var.disk_type
    disk_size_gb = var.disk_size_gb
    image_type   = "COS_CONTAINERD"

    service_account = google_service_account.nodes.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"] # access limited by IAM, not scopes

    tags   = var.node_network_tags
    labels = var.node_labels

    # Pods get Workload Identity credentials, never the node's.
    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }
  }
}
