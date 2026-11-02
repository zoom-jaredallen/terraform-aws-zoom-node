# Changelog

All notable changes to this module are documented here. Releases follow Semantic Versioning.

## [Unreleased]

### Added

- Maintained GovTech, Sydney, Tokyo, and US West deployment roots pinned to the immutable `v0.4.0` module release.
- Capacity-preflight outputs and operator workflows for each maintained deployment.

### Changed

- Preserve the US West production and development AMIs through explicit customer-owned image inputs.
- Validate deployment roots alongside examples in the repository release gate.

## [0.4.0] - 2026-11-03

### Added

- Customer-owned production and development AMI maps through the top-level `image_ids` input.
- Plan-time validation that each distinct selected AMI is visible, available, and `x86_64` in the active AWS region.
- A focused customer AMI catalog example and private-image onboarding guidance.
- Configurable global, group, explicit-node, and stable-key EC2 create timeouts.
- Exact Availability Zone instance-offering validation and a nonsensitive capacity request manifest.
- An optional EC2 Capacity Manager preflight supporting saved Terraform plans, manual checks, mixed markets, CI score thresholds, and secure plan extraction.
- Bounded AWS provider retries in maintained example roots.

### Changed

- Removed private Zoom AMI IDs from the reusable module catalog. Deployments upgrading to the next release must supply a customer-accessible AMI unless they already use an exact or legacy AWS image override.

## [0.3.0] - 2026-11-02

### Added

- Support `g5.12xlarge` as an AI Services override with an exact `ens5` cloud-init NIC mapping for four NVIDIA A10G GPUs.

## [0.2.1] - 2026-10-27

### Fixed

- Preserve legacy AWS provider private-IP list mode while adopting existing ENIs into `explicit_nodes`, preventing a migration-only ENI configuration update.

## [0.2.0] - 2026-10-27

### Added

- Split AWS resource ownership into private `network`, `node`, and `storage-access` implementation modules while retaining the root module as a compatible facade.
- Added retained state moves and a repository migration-contract check for the flat module extraction.
- Expanded native Terraform contract coverage from 8 to 30 plan-only tests across every workload, networking modes, Availability Zone placement, NAT, Spot, AMI channels, NIC mappings, IP validation, S3 modes, and per-node overrides.
- Added a repository gate that prevents required contract categories from being removed silently.
- Added exact `explicit_nodes` inventory for preserving stable node identities, hostnames, private IPs, external security groups, external IAM profiles, and source/destination-check settings during deployment adoption.
- Added generic Hybrid Recording storage through `aws.s3_bucket_access["hybrid_recording"]` and stable, non-blocking warnings for compatibility inputs scheduled for removal in `v1.0.0`.

### Deprecated

- Deprecated `enable_least_privilege_egress`, `aws.subnet_cidrs`, `aws.network_interface_names_by_instance_family`, `aws.enable_public_ipv4_on_boot`, the dedicated `hybrid_recording_s3_*` inputs, and the legacy Hybrid Recording bucket-name output. All remain functional in `v0.2.x`.

### Fixed

- Use the immutable GitHub release tag in consumer examples while Terraform Registry publication is disabled.
- Correct standalone repository paths in the example instructions.
- Remove duplicated AMI overrides from the smoke example so it exercises the shared image catalog.

## [0.1.0] - 2026-10-27

### Added

- AWS-native Zoom Node deployments for Meetings Hybrid, Hybrid Recording, Meeting Survivability, Web Application Gateway, AI Services, and Phone Local Survivability.
- New or existing VPC deployment modes, advanced node groups, public/private subnet tiers, NAT Gateway support, On-Demand and Spot instances, workload catalogs, and production/development AMI channels.
- Workload-specific standalone security-group rules with explicit egress profiles.
- Optional customer-managed KMS keys, S3 versioning/lifecycle, CloudWatch Logs retention, and granular bucket access.
- Native Terraform contract tests and generic new-VPC, existing-VPC, and smoke examples.
