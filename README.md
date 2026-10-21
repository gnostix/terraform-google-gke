# terraform-google-gke

Reusable Terraform module for a **GKE Standard cluster** with one managed node pool,
a dedicated least-privilege node service account, Workload Identity and the
IAM-authorised DNS control-plane endpoint.

> **On-demand nodes by default.** Set `spot = true` to use Spot VMs: 60-91% cheaper, but Google
> can reclaim them at any time (auto-repair brings a replacement). Good for dev/test and
> interruption-tolerant batch work; not for workloads that must not be interrupted.

## Usage

```hcl
module "gke" {
  source = "git::https://github.com/gnostix/terraform-google-gke.git?ref=v1.0.0"

  project_id          = "my-project"
  name                = "my-cluster"
  location            = "europe-west1-b"   # zone => zonal, region => regional
  network_id          = google_compute_network.vpc.id
  subnet_id           = google_compute_subnetwork.subnet.id
  pods_range_name     = "pods"
  services_range_name = "services"
}
```

Scale-to-zero node pool (since v1.1.0):

```hcl
  spot        = true
  autoscaling = { min_nodes = 0, max_nodes = 3 }
```

Always pin `?ref=` to a **tag** (or a commit SHA), never a branch.
A full, runnable example is in [`examples/basic`](examples/basic).

## What it creates

| Resource | Address in state |
|---|---|
| Node service account | `google_service_account.nodes` |
| Node SA roles (`container.defaultNodeServiceAccount`, `artifactregistry.reader`) | `google_project_iam_member.nodes["<role>"]` |
| Cluster (default pool removed) | `google_container_cluster.this` |
| Node pool `<name>-pool` | `google_container_node_pool.default` |

Resource addresses are part of the contract: they only change in a MAJOR release,
and then with `moved` blocks.

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `project_id` | string | — **required** | Project hosting the cluster |
| `name` | string | — **required** | Cluster name, 1-24 chars; prefixes `<name>-pool`, `<name>-nodes` |
| `location` | string | — **required** | Zone (zonal) or region (regional) |
| `network_id` | string | — **required** | VPC id / self link |
| `subnet_id` | string | — **required** | Subnet id / self link |
| `pods_range_name` | string | — **required** | Secondary range for pods |
| `services_range_name` | string | — **required** | Secondary range for Services |
| `deletion_protection` | bool | `true` | Block `terraform destroy` of the cluster |
| `private_nodes` | bool | `false` | Nodes without external IPs (needs NAT for egress) |
| `dns_endpoint_allow_external` | bool | `true` | Allow the DNS endpoint from outside Google Cloud |
| `release_channel` | string | `"REGULAR"` | RAPID, REGULAR, STABLE, EXTENDED |
| `logging_components` | list(string) | `["SYSTEM_COMPONENTS","WORKLOADS"]` | Cloud Logging components |
| `monitoring_components` | list(string) | `["SYSTEM_COMPONENTS"]` | Cloud Monitoring components |
| `managed_prometheus` | bool | `true` | Managed Service for Prometheus |
| `enable_secret_manager_addon` | bool | `false` | GKE Secret Manager CSI add-on |
| `machine_type` | string | `"e2-medium"` | Node machine type |
| `node_count` | number | `1` | Fixed node count (per zone if regional); ignored with `autoscaling` |
| `autoscaling` | object | `null` | `{ min_nodes, max_nodes, location_policy = "ANY" }` per zone; `null` = fixed size |
| `spot` | bool | `false` | Spot VMs (cheaper, interruptible) |
| `disk_type` | string | `"pd-balanced"` | pd-standard, pd-balanced, pd-ssd |
| `disk_size_gb` | number | `100` | Boot disk size, >= 10 |
| `node_network_tags` | list(string) | `[]` | Network tags for firewall rules |
| `node_labels` | map(string) | `{ pool = "default" }` | Kubernetes node labels |

## Outputs

| Name | Description |
|---|---|
| `cluster_name` | Cluster name |
| `cluster_id` | `projects/<p>/locations/<l>/clusters/<name>` |
| `location` | Zone or region |
| `endpoint` | IP of the classic control-plane endpoint |
| `ca_certificate` | Cluster CA (base64, sensitive) for IP-endpoint clients |
| `dns_endpoint` | IAM-authorised control-plane FQDN |
| `workload_pool` | `<project>.svc.id.goog` |
| `node_service_account` | Node SA email |
| `node_pool_name` | Node pool name |

## Requirements

| | Version |
|---|---|
| Terraform | `>= 1.9` |
| hashicorp/google | `>= 7.0, < 8.0` |

The module does **not** configure a provider and does **not** commit a lock file:
the calling root module owns both.

## Versioning

[Semantic Versioning](https://semver.org): `vMAJOR.MINOR.PATCH` git tags.

| Change | Bump |
|---|---|
| Bug fix, docs, no plan change for consumers | PATCH |
| New optional input/output, default behaviour unchanged | MINOR |
| Renamed/removed input or output, changed default, resource replacement | MAJOR (with upgrade notes in CHANGELOG) |

## Development

```bash
git config core.hooksPath .githooks   # fmt + validate + test before each commit
terraform init -backend=false
terraform test                        # mocked provider: no GCP access, no cost
```
