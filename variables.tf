# =============================================================================
# Required
# =============================================================================
variable "project_id" {
  description = "GCP project that hosts the cluster, its node pool and node service account."
  type        = string
}

variable "name" {
  description = "Cluster name. Also prefixes the node pool (<name>-pool) and node SA (<name>-nodes)."
  type        = string

  validation {
    # SA account_id max 30 chars: "<name>-nodes" => name <= 24.
    condition     = can(regex("^[a-z]([a-z0-9-]{0,22}[a-z0-9])?$", var.name))
    error_message = "name: 1-24 chars, lowercase letters/digits/hyphens, start with a letter, not end with a hyphen."
  }
}

variable "location" {
  description = "A ZONE (e.g. europe-west1-b) => zonal cluster (free-tier fee credit). A REGION (e.g. europe-west1) => regional cluster (HA control plane, node pool replicated in 3 zones)."
  type        = string

  validation {
    condition     = can(regex("^[a-z]+-[a-z]+[0-9]+(-[a-z])?$", var.location))
    error_message = "location must be a GCP region (europe-west1) or zone (europe-west1-b)."
  }
}

variable "network_id" {
  description = "VPC network id or self link."
  type        = string
}

variable "subnet_id" {
  description = "Subnetwork id or self link. Must contain the two secondary ranges below."
  type        = string
}

variable "pods_range_name" {
  description = "Name of the subnet's secondary range for pod IPs (VPC-native cluster)."
  type        = string
}

variable "services_range_name" {
  description = "Name of the subnet's secondary range for Service ClusterIPs."
  type        = string
}

# =============================================================================
# Optional - cluster
# =============================================================================
variable "deletion_protection" {
  description = "Terraform refuses to destroy the cluster while true. Set false only for disposable environments."
  type        = bool
  default     = true
}

variable "private_nodes" {
  description = "Nodes without external IPs. Requires Cloud NAT (or Private Google Access only) for egress."
  type        = bool
  default     = false
}

variable "dns_endpoint_allow_external" {
  description = "Allow user traffic to the IAM-authorised DNS control-plane endpoint from outside Google Cloud (laptops, GitHub runners)."
  type        = bool
  default     = true
}

variable "release_channel" {
  description = "GKE release channel: RAPID | REGULAR | STABLE | EXTENDED."
  type        = string
  default     = "REGULAR"

  validation {
    condition     = contains(["RAPID", "REGULAR", "STABLE", "EXTENDED"], var.release_channel)
    error_message = "release_channel must be one of RAPID, REGULAR, STABLE, EXTENDED."
  }
}

variable "logging_components" {
  description = "Cloud Logging components. [\"SYSTEM_COMPONENTS\"] alone drops workload logs (cheaper)."
  type        = list(string)
  default     = ["SYSTEM_COMPONENTS", "WORKLOADS"]
}

variable "monitoring_components" {
  description = "Cloud Monitoring components."
  type        = list(string)
  default     = ["SYSTEM_COMPONENTS"]
}

variable "managed_prometheus" {
  description = "Google Cloud Managed Service for Prometheus (billed by samples ingested)."
  type        = bool
  default     = true
}

variable "enable_secret_manager_addon" {
  description = "Install the GKE Secret Manager add-on (CSI driver secrets-store-gke.csi.k8s.io)."
  type        = bool
  default     = false
}

# =============================================================================
# Optional - node pool
# =============================================================================
variable "machine_type" {
  description = "Node machine type."
  type        = string
  default     = "e2-medium"
}

variable "node_count" {
  description = "Fixed number of nodes (per zone for regional clusters). Ignored when `autoscaling` is set."
  type        = number
  default     = 1

  validation {
    condition     = var.node_count >= 0 && floor(var.node_count) == var.node_count
    error_message = "node_count must be a whole number >= 0."
  }
}

variable "spot" {
  description = "Use Spot VMs for the node pool: 60-91% cheaper, but Google can reclaim them at any time (auto-repair brings a replacement). Default false = standard on-demand VMs; set true for interruption-tolerant workloads (dev, batch with checkpointing)."
  type        = bool
  default     = false
}

variable "disk_type" {
  description = "Node boot disk type."
  type        = string
  default     = "pd-balanced"

  validation {
    condition     = contains(["pd-standard", "pd-balanced", "pd-ssd"], var.disk_type)
    error_message = "disk_type must be pd-standard, pd-balanced or pd-ssd."
  }
}

variable "disk_size_gb" {
  description = "Node boot disk size in GB."
  type        = number
  default     = 100

  validation {
    condition     = var.disk_size_gb >= 10
    error_message = "disk_size_gb must be >= 10."
  }
}

variable "node_network_tags" {
  description = "Network tags on node VMs (targets for firewall rules)."
  type        = list(string)
  default     = []
}

variable "node_labels" {
  description = "Kubernetes labels on nodes (usable in nodeSelector)."
  type        = map(string)
  default = {
    pool = "default"
  }
}

variable "autoscaling" {
  description = <<-EOT
    Cluster autoscaler for the node pool. null (default) = fixed size from node_count.
    min_nodes / max_nodes are PER ZONE. min_nodes = 0 lets an idle pool scale to zero
    (pods are scheduled again when nodes come back). location_policy: BALANCED spreads
    nodes across zones, ANY prefers zones with capacity (good for Spot).
  EOT
  type = object({
    min_nodes       = number
    max_nodes       = number
    location_policy = optional(string, "ANY")
  })
  default = null

  validation {
    condition = var.autoscaling == null || try(
      var.autoscaling.min_nodes >= 0 &&
      var.autoscaling.max_nodes >= 1 &&
      var.autoscaling.max_nodes >= var.autoscaling.min_nodes,
    false)
    error_message = "autoscaling: need 0 <= min_nodes <= max_nodes and max_nodes >= 1."
  }

  validation {
    condition     = var.autoscaling == null || try(contains(["BALANCED", "ANY"], var.autoscaling.location_policy), false)
    error_message = "autoscaling.location_policy must be BALANCED or ANY."
  }
}
