output "cluster_name" {
  description = "Cluster name."
  value       = google_container_cluster.this.name
}

output "cluster_id" {
  description = "Cluster id: projects/<p>/locations/<l>/clusters/<name>."
  value       = google_container_cluster.this.id
}

output "location" {
  description = "Cluster location (zone or region)."
  value       = google_container_cluster.this.location
}

output "endpoint" {
  description = "IP of the classic control-plane endpoint (use with ca_certificate)."
  value       = google_container_cluster.this.endpoint
}

output "ca_certificate" {
  description = "Base64-encoded cluster CA certificate, for clients of the IP endpoint."
  value       = try(google_container_cluster.this.master_auth[0].cluster_ca_certificate, null)
  sensitive   = true
}

output "dns_endpoint" {
  description = "IAM-authorised control-plane FQDN (works from any network, auth via container.clusters.connect)."
  value       = google_container_cluster.this.control_plane_endpoints_config[0].dns_endpoint_config[0].endpoint
}

output "workload_pool" {
  description = "Workload Identity pool (<project>.svc.id.goog) for IAM principals of Kubernetes SAs."
  value       = google_container_cluster.this.workload_identity_config[0].workload_pool
}

output "node_service_account" {
  description = "Email of the node service account."
  value       = google_service_account.nodes.email
}

output "node_pool_name" {
  description = "Name of the module's node pool."
  value       = google_container_node_pool.default.name
}
