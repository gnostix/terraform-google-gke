# Minimal, self-contained usage example - also validated in CI.
# A consumer would use the git source instead of "../..", e.g.:
#   source = "git::https://github.com/gnostix/terraform-google-gke.git?ref=v1.0.0"

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
  name                    = "example-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "subnet" {
  name          = "example-europe-west1"
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

# --- the module: only required inputs + one override ---
module "gke" {
  source = "../.."

  project_id          = var.project_id
  name                = "example"
  location            = "europe-west1-b" # zone => zonal cluster
  network_id          = google_compute_network.vpc.id
  subnet_id           = google_compute_subnetwork.subnet.id
  pods_range_name     = "pods"
  services_range_name = "services"

  deletion_protection = false # disposable example
}

output "get_credentials" {
  value = "gcloud container clusters get-credentials ${module.gke.cluster_name} --location ${module.gke.location} --project ${var.project_id} --dns-endpoint"
}
