# Changelog

All notable changes to this module. Format: [Keep a Changelog](https://keepachangelog.com),
versions: [SemVer](https://semver.org).

## [Unreleased]

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

[Unreleased]: https://github.com/gnostix/terraform-google-gke/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/gnostix/terraform-google-gke/releases/tag/v1.0.0
