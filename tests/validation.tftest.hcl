# Bad inputs must fail at PLAN time with our message - not as a GCP API error.

mock_provider "google" {}

variables {
  project_id          = "test-project"
  name                = "unit"
  location            = "europe-west1-b"
  network_id          = "vpc"
  subnet_id           = "subnet"
  pods_range_name     = "pods"
  services_range_name = "services"
}

run "rejects_name_too_long" {
  command = plan
  variables {
    name = "this-name-is-way-too-long-for-a-sa"
  }
  expect_failures = [var.name]
}

run "rejects_uppercase_name" {
  command = plan
  variables {
    name = "MyCluster"
  }
  expect_failures = [var.name]
}

run "rejects_unknown_release_channel" {
  command = plan
  variables {
    release_channel = "NIGHTLY"
  }
  expect_failures = [var.release_channel]
}

run "rejects_bad_location" {
  command = plan
  variables {
    location = "europe"
  }
  expect_failures = [var.location]
}

run "rejects_empty_node_pools" {
  command = plan
  variables {
    node_pools = {}
  }
  expect_failures = [var.node_pools]
}

run "rejects_bad_pool_key" {
  command = plan
  variables {
    node_pools = { "Batch_Pool" = {} }
  }
  expect_failures = [var.node_pools]
}

run "rejects_tiny_disk" {
  command = plan
  variables {
    node_pools = { default = { disk_size_gb = 5 } }
  }
  expect_failures = [var.node_pools]
}

run "rejects_autoscaling_min_greater_than_max" {
  command = plan
  variables {
    node_pools = { default = { autoscaling = { min_nodes = 3, max_nodes = 1 } } }
  }
  expect_failures = [var.node_pools]
}

run "rejects_bad_taint_effect" {
  command = plan
  variables {
    node_pools = { default = { taints = [{ key = "a", value = "b", effect = "NoSchedule" }] } }
  }
  expect_failures = [var.node_pools]
}
