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
    condition     = length(google_container_node_pool.pools) == 1 && contains(keys(google_container_node_pool.pools), "default")
    error_message = "Default node_pools must contain exactly one pool, \"default\"."
  }
  assert {
    condition     = google_container_node_pool.pools["default"].name == "unit-pool"
    error_message = "Pool key \"default\" must keep the v1 name <name>-pool (no replacement on upgrade)."
  }
  assert {
    condition     = google_container_node_pool.pools["default"].node_config[0].spot == false
    error_message = "spot must default to false (on-demand nodes)."
  }
  assert {
    condition     = google_container_node_pool.pools["default"].node_config[0].disk_type == "pd-balanced"
    error_message = "disk_type must default to pd-balanced."
  }
  assert {
    condition     = google_container_node_pool.pools["default"].node_count == 1
    error_message = "Without autoscaling a pool must have a fixed node_count (default 1)."
  }
  assert {
    condition     = length(google_container_node_pool.pools["default"].node_config[0].labels) == 1 && google_container_node_pool.pools["default"].node_config[0].labels["pool"] == "default"
    error_message = "Pool label must be pool = <key> (same as v1 default)."
  }
  assert {
    condition     = google_container_cluster.this.secret_manager_config[0].enabled == false
    error_message = "Secret Manager add-on must be off by default."
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

# A typical split: small on-demand system pool + Spot batch pool that scales to zero.
run "system_plus_spot_batch_pool" {
  command = plan

  variables {
    node_pools = {
      default = {}
      batch = {
        machine_type = "n2-standard-8"
        spot         = true
        autoscaling  = { min_nodes = 0, max_nodes = 5 }
        labels       = { workload = "batch" }
        taints       = [{ key = "workload", value = "batch", effect = "NO_SCHEDULE" }]
      }
    }
  }

  assert {
    condition     = google_container_node_pool.pools["batch"].name == "unit-batch"
    error_message = "Non-default pools must be named <name>-<key>."
  }
  assert {
    condition     = google_container_node_pool.pools["batch"].node_config[0].spot == true
    error_message = "batch pool must be Spot."
  }
  assert {
    condition     = google_container_node_pool.pools["batch"].autoscaling[0].min_node_count == 0
    error_message = "batch pool must scale to zero."
  }
  assert {
    condition     = length(google_container_node_pool.pools["batch"].node_config[0].labels) == 2 && google_container_node_pool.pools["batch"].node_config[0].labels["pool"] == "batch" && google_container_node_pool.pools["batch"].node_config[0].labels["workload"] == "batch"
    error_message = "labels must merge pool = <key> with the pool's labels."
  }
  assert {
    condition     = google_container_node_pool.pools["batch"].node_config[0].taint[0].effect == "NO_SCHEDULE"
    error_message = "taints must be rendered."
  }
  assert {
    condition     = google_container_node_pool.pools["default"].node_config[0].spot == false
    error_message = "default pool must stay on-demand when another pool is Spot."
  }
}
