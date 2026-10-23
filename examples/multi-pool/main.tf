# Two node pools: a small on-demand "default" pool for system pods and
# always-on services, plus a Spot "batch" pool that scales to zero when idle.
# A consumer would use the git source instead of "../..", e.g.:
#   source = "git::https://github.com/gnostix/terraform-google-gke.git?ref=v2.0.0"

terraform {
  required_version = ">= 1.9"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 7.0, < 8.0"
    }
  }
}

variable "project_id" {
  type = string
}

provider "google" {
  project = var.project_id
  region  = "europe-west1"
}

# --- the network the module expects (VPC + subnet with 2 secondary ranges) ---
resource "google_compute_network" "vpc" {
  name                    = "multipool-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "subnet" {
  name          = "multipool-europe-west1"
  region        = "europe-west1"
  network       = google_compute_network.vpc.id
  ip_cidr_range = "10.10.0.0/20"

  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = "10.20.0.0/16"
  }
  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = "10.30.0.0/20"
  }
}

module "gke" {
  source = "../.."

  project_id          = var.project_id
  name                = "multipool"
  location            = "europe-west1-b"
  network_id          = google_compute_network.vpc.id
  subnet_id           = google_compute_subnetwork.subnet.id
  pods_range_name     = "pods"
  services_range_name = "services"

  deletion_protection = false # disposable example

  node_pools = {
    # Pool 1 -> GKE name "multipool-pool"
    # On-demand, fixed 1 node: kube-system pods (DNS, metrics...) live here,
    # which is what allows the batch pool below to reach zero nodes.
    default = {
      machine_type = "e2-medium"
      disk_size_gb = 50
    }

    # Pool 2 -> GKE name "multipool-batch"
    # Spot, autoscaled 0..3 nodes. The taint keeps ordinary pods away;
    # only pods that tolerate it (and select it) land here.
    batch = {
      machine_type = "e2-standard-4"
      spot         = true
      autoscaling  = { min_nodes = 0, max_nodes = 3 }
      disk_size_gb = 50
      labels       = { workload = "batch" } # node label: pool=batch, workload=batch
      taints = [{
        key    = "workload"
        value  = "batch"
        effect = "NO_SCHEDULE"
      }]
    }
  }
}

output "node_pool_names" {
  value = module.gke.node_pool_names # { default = "multipool-pool", batch = "multipool-batch" }
}

# A pod that runs on the batch pool needs BOTH of these in its spec:
#
#   nodeSelector:
#     workload: batch
#   tolerations:
#     - key: workload
#       operator: Equal
#       value: batch
#       effect: NoSchedule
#
# When such pods are pending, the autoscaler adds batch nodes (0 -> n);
# ~10 minutes after they finish, it removes them again (n -> 0).
