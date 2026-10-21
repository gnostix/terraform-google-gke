# -----------------------------------------------------------------------------
# Dedicated node service account (instead of the Compute Engine default SA,
# which usually has Editor - and every pod could borrow it via metadata).
# -----------------------------------------------------------------------------
resource "google_service_account" "nodes" {
  project      = var.project_id
  account_id   = "${var.name}-nodes"
  display_name = "GKE nodes for ${var.name}"
}

locals {
  node_roles = [
    "roles/container.defaultNodeServiceAccount", # logs, metrics, metadata - the documented minimum
    "roles/artifactregistry.reader",             # pull images from Artifact Registry
  ]
}

resource "google_project_iam_member" "nodes" {
  for_each = toset(local.node_roles)

  project = var.project_id
  role    = each.value
  member  = google_service_account.nodes.member
}
