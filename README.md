# terraform-google-gke

Reusable Terraform module for a **GKE Standard cluster** with one or more managed node pools,
a dedicated least-privilege node service account, Workload Identity and the
IAM-authorised DNS control-plane endpoint.

> **On-demand nodes by default.** Set `spot = true` on a pool to use Spot VMs: 60-91% cheaper, but
> Google can reclaim them at any time (auto-repair brings a replacement). Good for dev/test and
> interruption-tolerant batch work; not for workloads that must not be interrupted.

## Usage

```hcl
module "gke" {
  source = "git::https://github.com/gnostix/terraform-google-gke.git?ref=v2.0.0"

  project_id          = "my-project"
  name                = "my-cluster"
  location            = "europe-west1-b"   # zone => zonal, region => regional
  network_id          = google_compute_network.vpc.id
  subnet_id           = google_compute_subnetwork.subnet.id
  pods_range_name     = "pods"
  services_range_name = "services"
}
```

System pool + Spot batch pool that scales to zero (v2.0.0+):

```hcl
  node_pools = {
    default = {}                                   # small on-demand pool for system pods
    batch = {
      machine_type = "n2-standard-8"
      spot         = true
      autoscaling  = { min_nodes = 0, max_nodes = 5 }
      labels       = { workload = "batch" }
      taints       = [{ key = "workload", value = "batch", effect = "NO_SCHEDULE" }]
    }
  }
```
Batch pods then need `nodeSelector: { workload: batch }` and a toleration for `workload=batch:NoSchedule`.

Always pin `?ref=` to a **tag** (or a commit SHA), never a branch.
Runnable examples: [`examples/basic`](examples/basic) (one default pool) and
[`examples/multi-pool`](examples/multi-pool) (on-demand system pool + Spot batch pool scaling to zero).

## What it creates

| Resource | Address in state |
|---|---|
| Node service account | `google_service_account.nodes` |
| Node SA roles (`container.defaultNodeServiceAccount`, `artifactregistry.reader`) | `google_project_iam_member.nodes["<role>"]` |
| Cluster (default pool removed) | `google_container_cluster.this` |
| Node pools: key `default` → `<name>-pool`, others → `<name>-<key>` | `google_container_node_pool.pools["<key>"]` |

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
| `node_pools` | map(object) | `{ default = {} }` | Node pools by key; see below |

### `node_pools` attributes (all optional)

| Attribute | Default | Notes |
|---|---|---|
| `machine_type` | `"e2-medium"` | |
| `node_count` | `1` | fixed size per zone; ignored with `autoscaling` |
| `autoscaling` | `null` | `{ min_nodes, max_nodes, location_policy = "ANY" }` per zone; `min_nodes = 0` = scale to zero |
| `spot` | `false` | Spot VMs (cheaper, interruptible) |
| `disk_type` | `"pd-balanced"` | pd-standard, pd-balanced, pd-ssd |
| `disk_size_gb` | `100` | >= 10 |
| `network_tags` | `[]` | firewall targets |
| `labels` | `{}` | merged with `pool = <key>` |
| `taints` | `[]` | `[{ key, value, effect }]`, effect NO_SCHEDULE / PREFER_NO_SCHEDULE / NO_EXECUTE |

Pool keys: 1-15 chars, lowercase, start with a letter.

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
| `node_pool_names` | Map: pool key => GKE node pool name |

## Upgrading from 1.x to 2.0.0

The single pool's inputs moved into `node_pools["default"]`. The module contains a `moved`
block, so **if you keep the key `default`, the existing pool is not recreated**.

```hcl
# 1.x                                   # 2.0.0
spot              = true                node_pools = {
disk_type         = "pd-standard"         default = {
disk_size_gb      = 30                      spot         = true
node_network_tags = ["my-tag"]              disk_type    = "pd-standard"
autoscaling       = { min_nodes = 1,        disk_size_gb = 30
                      max_nodes = 2 }       network_tags = ["my-tag"]
                                            autoscaling  = { min_nodes = 1, max_nodes = 2 }
                                          }
                                        }
```

Expected plan after the upgrade:
`module.<call>.google_container_node_pool.default has moved to module.<call>.google_container_node_pool.pools["default"]`
and **0 to add, 0 to change, 0 to destroy**. Anything else means a value differs: compare with your 1.x inputs.

- `node_labels` → `node_pools.default.labels` (`pool = "default"` is now always added).
- Output `node_pool_name` → `node_pool_names["default"]`.

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
