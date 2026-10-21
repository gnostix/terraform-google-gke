# terraform test - plan-only, with a MOCKED google provider:
# no GCP credentials, no API calls, no cost. Runs in seconds in CI.

mock_provider "google" {}

variables {
  project_id          = "test-project"
  name                = "unit"
  location            = "europe-west1-b"
  network_id          = "projects/test-project/global/networks/vpc"
  subnet_id           = "projects/test-project/regions/europe-west1/subnetworks/subnet"
  pods_range_name     = "pods"
  services_range_name = "services"
}

# The module's defaults ARE its contract - a test fails if one changes by accident.
run "defaults_are_the_documented_contract" {
  command = plan

  assert {
    condition     = google_container_cluster.this.deletion_protection == true
    error_message = "deletion_protection must default to true."
  }
  assert {
    condition     = google_container_node_pool.default.node_config[0].spot == false
    error_message = "spot must default to false (on-demand nodes)."
  }
  assert {
    condition     = google_container_node_pool.default.node_config[0].disk_type == "pd-balanced"
    error_message = "disk_type must default to pd-balanced."
  }
  assert {
    condition     = google_container_cluster.this.secret_manager_config[0].enabled == false
    error_message = "Secret Manager add-on must be off by default."
  }
  assert {
    condition     = google_container_node_pool.default.node_count == 1
    error_message = "Without autoscaling the pool must have a fixed node_count (default 1)."
  }
  assert {
    condition     = google_container_node_pool.default.name == "unit-pool"
    error_message = "node pool name must be <name>-pool."
  }
  assert {
    condition     = google_service_account.nodes.account_id == "unit-nodes"
    error_message = "node SA id must be <name>-nodes."
  }
}

run "private_nodes_renders_the_block" {
  command = plan

  variables {
    private_nodes = true
  }

  assert {
    condition     = google_container_cluster.this.private_cluster_config[0].enable_private_nodes == true
    error_message = "private_nodes = true must enable private nodes."
  }
}

run "consumer_can_opt_into_spot" {
  command = plan

  variables {
    spot = true
  }

  assert {
    condition     = google_container_node_pool.default.node_config[0].spot == true
    error_message = "spot = true must produce Spot nodes."
  }
}

run "autoscaling_renders_the_block" {
  command = plan

  variables {
    autoscaling = {
      min_nodes = 0
      max_nodes = 3
    }
  }

  assert {
    condition     = google_container_node_pool.default.autoscaling[0].min_node_count == 0
    error_message = "autoscaling.min_nodes must map to min_node_count."
  }
  assert {
    condition     = google_container_node_pool.default.autoscaling[0].max_node_count == 3
    error_message = "autoscaling.max_nodes must map to max_node_count."
  }
  assert {
    condition     = google_container_node_pool.default.autoscaling[0].location_policy == "ANY"
    error_message = "location_policy must default to ANY."
  }
}
