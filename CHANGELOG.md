# Changelog

All notable changes to this module are documented here. Releases follow Semantic Versioning.

## [Unreleased]

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
