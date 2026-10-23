# Changelog

All notable changes to this module. Format: [Keep a Changelog](https://keepachangelog.com),
versions: [SemVer](https://semver.org).

## [Unreleased]

## [2.0.0] - 2026-10-23

### Changed (BREAKING)
- Node pools are now configured through one map, `node_pools` (default `{ default = {} }`),
  creating `google_container_node_pool.pools["<key>"]`. Key `default` keeps the name `<name>-pool`;
  other keys are named `<name>-<key>`.
- Output `node_pool_name` replaced by `node_pool_names` (map of key => name).

### Removed (BREAKING)
- Top-level inputs `machine_type`, `node_count`, `autoscaling`, `spot`, `disk_type`,
  `disk_size_gb`, `node_network_tags`, `node_labels`: now attributes of each `node_pools` entry
  (`node_network_tags` → `network_tags`, `node_labels` → `labels`).

### Added
- Multiple node pools, per-pool `taints`, label `pool = <key>` on every pool.
- `moved` block `google_container_node_pool.default` → `google_container_node_pool.pools["default"]`:
  upgrading keeps the existing pool.

### Upgrade notes
- Move your 1.x pool inputs into `node_pools = { default = { ... } }` (see README, "Upgrading from 1.x").
  Keep the key `default`; the plan must show the pool as *moved* and 0 changes.

## [1.1.0] - 2026-10-21

### Added
- `autoscaling` input (`{ min_nodes, max_nodes, location_policy }`, default `null`): enables the
  cluster autoscaler on the node pool, including scale-to-zero. With the default, behaviour is
  unchanged (fixed `node_count`), so this is a MINOR release.

## [1.0.0] - 2026-10-21

### Added
- GKE Standard cluster (zonal or regional via `location`) with the default node pool removed.
- One managed node pool `<name>-pool`: on-demand by default (`spot = true` opt-in), COS_CONTAINERD,
  Shielded VM, `GKE_METADATA`.
- Dedicated node service account `<name>-nodes` with `container.defaultNodeServiceAccount`
  and `artifactregistry.reader`.
- Workload Identity, DNS-based control-plane endpoint, optional Secret Manager add-on.
- Input validation for `name`, `location`, `release_channel`, `node_count`, `disk_type`, `disk_size_gb`.
- Mocked `terraform test` suite and CI (fmt, validate, test on Terraform 1.9 and 1.13).

[Unreleased]: https://github.com/gnostix/terraform-google-gke/compare/v2.0.0...HEAD
[2.0.0]: https://github.com/gnostix/terraform-google-gke/compare/v1.1.0...v2.0.0
[1.1.0]: https://github.com/gnostix/terraform-google-gke/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/gnostix/terraform-google-gke/releases/tag/v1.0.0
