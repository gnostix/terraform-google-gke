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
# Node pools (v2.0.0: one map replaces the v1 top-level pool inputs)
# =============================================================================
variable "node_pools" {
  description = <<-EOT
    Node pools keyed by a short name. Key "default" keeps the v1 pool name "<name>-pool";
    any other key becomes "<name>-<key>". Every attribute is optional:
      machine_type  (e2-medium)     node_count (1, ignored with autoscaling)
      spot          (false)         autoscaling ({min_nodes, max_nodes, location_policy="ANY"} per zone, null = fixed size)
      disk_type     (pd-balanced)   disk_size_gb (100)
      network_tags  ([])            labels ({}; "pool = <key>" is always added)
      taints        ([])            [{ key, value, effect = NO_SCHEDULE | PREFER_NO_SCHEDULE | NO_EXECUTE }]
  EOT
  type = map(object({
    machine_type = optional(string, "e2-medium")
    node_count   = optional(number, 1)
    autoscaling = optional(object({
      min_nodes       = number
      max_nodes       = number
      location_policy = optional(string, "ANY")
    }))
    spot         = optional(bool, false)
    disk_type    = optional(string, "pd-balanced")
    disk_size_gb = optional(number, 100)
    network_tags = optional(list(string), [])
    labels       = optional(map(string), {})
    taints = optional(list(object({
      key    = string
      value  = string
      effect = string
    })), [])
  }))
  default = {
    default = {}
  }

  validation {
    condition     = length(var.node_pools) > 0
    error_message = "node_pools needs at least one pool."
  }

  validation {
    # "<name>-<key>" must fit GKE's 40-char pool name limit (name <= 24 + "-" + key <= 15).
    condition     = alltrue([for k in keys(var.node_pools) : can(regex("^[a-z]([a-z0-9-]{0,13}[a-z0-9])?$", k))])
    error_message = "node_pools keys: 1-15 chars, lowercase letters/digits/hyphens, start with a letter."
  }

  validation {
    condition     = alltrue([for p in values(var.node_pools) : contains(["pd-standard", "pd-balanced", "pd-ssd"], p.disk_type) && p.disk_size_gb >= 10])
    error_message = "node_pools: disk_type must be pd-standard, pd-balanced or pd-ssd, and disk_size_gb >= 10."
  }

  validation {
    condition     = alltrue([for p in values(var.node_pools) : p.node_count >= 0 && floor(p.node_count) == p.node_count])
    error_message = "node_pools: node_count must be a whole number >= 0."
  }

  validation {
    condition = alltrue([for p in values(var.node_pools) : p.autoscaling == null || try(
      p.autoscaling.min_nodes >= 0 && p.autoscaling.max_nodes >= 1 && p.autoscaling.max_nodes >= p.autoscaling.min_nodes &&
      contains(["BALANCED", "ANY"], p.autoscaling.location_policy),
    false)])
    error_message = "node_pools: autoscaling needs 0 <= min_nodes <= max_nodes, max_nodes >= 1, location_policy BALANCED or ANY."
  }

  validation {
    condition     = alltrue(flatten([for p in values(var.node_pools) : [for t in p.taints : contains(["NO_SCHEDULE", "PREFER_NO_SCHEDULE", "NO_EXECUTE"], t.effect)]]))
    error_message = "node_pools: taint effect must be NO_SCHEDULE, PREFER_NO_SCHEDULE or NO_EXECUTE."
  }
}
