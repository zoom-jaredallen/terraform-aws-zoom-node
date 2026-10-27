# Deployment Migration and Legacy Deprecation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Migrate all maintained Zoom Node deployment roots to the standalone module without infrastructure replacement, then deprecate redundant compatibility inputs for removal in `v1.0.0`.

**Architecture:** Extend the compatible root facade with an exact-node inventory while retaining `workloads` and `node_groups`. Deployments call only the root module; declarative `moved` blocks transfer existing state into the private `node` and `network` modules. Deprecations ship as documented, non-blocking warnings in a minor release and are removed only in the next major release.

**Tech Stack:** Terraform >= 1.7, AWS provider >= 6.0, native Terraform tests, terraform-docs, TFLint, Trivy, AWS CLI, jq.

**Spec:** `docs/superpowers/specs/2026-10-27-deployment-migration-and-deprecation-design.md`

## Global Constraints

- Never apply a plan containing an unapproved `delete`, `create_then_delete`, or `delete_then_create` action for a stateful AWS resource.
- Never apply when `terraform state list` is unexpectedly empty.
- Use an immutable Git tag for every deployment; never point a live deployment at a branch or mutable local checkout.
- Do not commit registration codes, passwords, generated plans, state files, `.env`, or `local.auto.tfvars`.
- Preserve existing resource IDs and network addresses through declarative state moves.
- Keep deployment-specific security groups and external IAM profiles externally owned during the first migration.
- Run module contract checks and deployment-specific plans before every migration commit.

## Review Focus

- Existing-state discovery: a missing backend or empty local state must halt rather than produce a creation plan.
- Address identity: exact node keys, EIP keys, and count/for_each indexes must match every `moved` destination.
- Existing dependencies: external security groups and IAM profiles must not be replaced by empty module-managed substitutes.
- Lifecycle drift: user data, private IP lists, kube-vip addresses, and externally added ENI IPs must retain their ignore-change behavior.
- Provider behavior: plans must be inspected in JSON for replacement actions, not accepted based only on human-readable summaries.

---

## File Structure

### Standalone module repository

- `variables.tf`: add `explicit_nodes`; mark compatibility inputs deprecated.
- `locals.tf`: normalize workload, grouped, and explicit nodes into the existing `local.node_records` contract.
- `validation.tf`: validate explicit identities, IPs, dependencies, and legacy/replacement conflicts.
- `security.tf`: exclude externally secured explicit nodes from managed security-profile creation.
- `storage.tf`: exclude external/no-profile nodes from IAM creation and support generic Hybrid Recording bucket access.
- `main.tf`: pass normalized external security/IAM selections to child modules.
- `modules/node/{variables,main}.tf`: accept per-node security-group IDs and nullable instance-profile names.
- `modules/storage-access/{variables,main,outputs}.tf`: create only managed profile keys and merge externally supplied profile names.
- `tests/explicit-nodes.tftest.hcl`: exact-node, external SG/IAM, and lifecycle contracts.
- `tests/deprecations.tftest.hcl`: replacement precedence and conflict contracts.
- `scripts/check-test-contract-coverage.sh`: require the new contract runs.
- `README.md`, `CHANGELOG.md`, `docs/terraform-upgrades.md`: document migration and deprecation lifecycle.

### Deployment repository

- `terraform/deployments/*/main.tf`: consume one immutable standalone-module tag.
- `terraform/deployments/*/migrations.tf`: retain deployment-specific cross-module state moves.
- `terraform/deployments/*/outputs.tf`: continue existing output names by delegating to module outputs.
- `terraform/deployments/*/README.md`: add preflight, plan-review, rollback, and post-apply checks.
- Split Sydney's single `main.tf` into conventional files during its migration, without changing behavior.

---

### Task 1: Establish Authoritative State and Migration Manifests

**Files:**
- Create: `docs/deployment-migration-manifest.md`
- Create: `scripts/capture-deployment-baseline.sh`
- Modify: `.gitignore`

**Interfaces:**
- Produces: one redacted manifest per deployment containing backend identity, region/account, state serial/lineage, resource addresses, AWS IDs, node names, IPs, instance types, AMIs, disks, SGs, IAM profiles, and EIPs.
- Consumes: no earlier task.

- [ ] Add a shell contract test that fails unless the baseline script refuses an empty state by default and writes only under a git-ignored `.migration/` directory.
- [ ] Run the contract and verify it fails because the script does not exist.
- [ ] Implement `capture-deployment-baseline.sh DEPLOYMENT_DIR`, using `terraform state pull`, `terraform show -json`, and read-only AWS CLI calls. Require `ALLOW_EMPTY_STATE=1` to record an intentionally empty deployment.
- [ ] Record that current local state is empty for `us-west-2-labcluster` and Sydney; resolve whether each is destroyed or uses another authoritative state before planning an apply.
- [ ] Capture Tokyo and GovTech baselines and verify their current state addresses against AWS instance, ENI, EIP, SG, IAM, VPC, and subnet IDs.
- [ ] Run the script tests and `git diff --check`.
- [ ] Commit the baseline tooling and redacted manifest.

### Task 2: Add Exact Explicit-Node Support to the Facade

**Files:**
- Modify: `variables.tf`, `locals.tf`, `compute.tf`, `security.tf`, `storage.tf`, `main.tf`, `validation.tf`
- Modify: `modules/node/variables.tf`, `modules/node/main.tf`
- Modify: `modules/storage-access/variables.tf`, `modules/storage-access/main.tf`, `modules/storage-access/outputs.tf`
- Create: `tests/explicit-nodes.tftest.hcl`

**Interfaces:**
- Produces: the exact `explicit_nodes` type declared in the spec, keyed by stable node identity; normalized records include exact `node_name`, `fqdn`, `private_ips`, `security_group_ids`, and nullable `iam_instance_profile_name`.
- Consumes: existing `local.node_records`, child `module.node`, and `module.storage_access` contracts.

- [ ] Add failing plan tests for two exact nodes with different instance types, exact hostnames/private IPs, external SG IDs, one external IAM profile, one null IAM profile, zero EIPs, and preserved source/destination checks.
- [ ] Add failing validation tests for duplicate identities across workloads/groups/explicit nodes, empty private-IP lists, IPs outside the selected subnet, EIP counts greater than private-IP counts, and simultaneous managed/external security or IAM ownership.
- [ ] Run `terraform test -filter=tests/explicit-nodes.tftest.hcl`; expect failures because `explicit_nodes` is undeclared.
- [ ] Add the typed `explicit_nodes` input and normalize it into `local.node_records` without altering existing workload or node-group keys.
- [ ] Update the node child module to use normalized `security_group_ids`; use a managed profile ID only when no external IDs are supplied.
- [ ] Make IAM instance-profile assignment nullable and create IAM resources only for managed profile keys.
- [ ] Preserve ENI private-IP and EC2 user-data ignore-change behavior for explicit nodes.
- [ ] Run the explicit-node tests, then all 30 existing native tests; expect all to pass.
- [ ] Update contract coverage and generated documentation.
- [ ] Commit the explicit-node capability.

### Task 3: Generalize Hybrid Recording Storage and Add Deprecation Warnings

**Files:**
- Modify: `variables.tf`, `locals.tf`, `storage.tf`, `validation.tf`
- Create: `deprecations.tf`
- Create: `tests/deprecations.tftest.hcl`
- Modify: `examples/aws-new-vpc/main.tf`
- Modify: `README.md`, `CHANGELOG.md`, `docs/terraform-upgrades.md`

**Interfaces:**
- Produces: generic `aws.s3_bucket_access["hybrid_recording"]` configuration targeting IAM profile key `HybridRecording`; non-blocking warnings for deprecated inputs.
- Consumes: Task 2's normalized managed/external IAM profile ownership.

- [ ] Add failing tests proving generic Hybrid Recording S3 access creates the same bucket controls and IAM policy as the dedicated inputs.
- [ ] Add failing tests that reject simultaneous generic and dedicated Hybrid Recording configuration.
- [ ] Add warning-contract tests for `check.deprecated_enable_least_privilege_egress`, `check.deprecated_subnet_cidrs`, `check.deprecated_instance_family_nic_map`, `check.deprecated_public_ipv4_on_boot`, and `check.deprecated_hybrid_recording_s3_inputs`.
- [ ] Implement generic Hybrid Recording access and retain the old inputs as precedence-compatible shims.
- [ ] Add non-blocking `check` assertions with direct replacement instructions for every deprecated input.
- [ ] Migrate `examples/aws-new-vpc` to generic S3 access and remove every deprecated input from maintained examples.
- [ ] Rename internal `legacy_iam_profile_configs` to `workload_iam_profile_configs` because it is not a public compatibility feature.
- [ ] Run deprecation tests and the full repository check.
- [ ] Commit deprecation warnings and example migration.

### Task 4: Release the Migration-Capable Module

**Files:**
- Modify: `CHANGELOG.md`
- Verify: module repository tag and GitHub release metadata

**Interfaces:**
- Produces: immutable `v0.2.0` module source used by Tasks 5-8.
- Consumes: Tasks 1-3 and a clean full repository check.

- [ ] Run `./scripts/check-repository.sh`; require exit code 0.
- [ ] Review `git diff v0.1.0...HEAD`, confirm no secret/local artifacts, and verify all moved blocks remain present.
- [ ] Create and push the `v0.2.0` tag only after confirming it does not already exist locally or remotely.
- [ ] Create release notes covering flat-module state moves, explicit nodes, deprecation warnings, and the no-replacement plan gate. Do not publish to the Terraform Registry.
- [ ] Verify a clean checkout can initialize each example using `?ref=v0.2.0`.

### Task 5: Migrate us-west-2-labcluster

**Files:**
- Modify: `terraform/deployments/us-west-2-labcluster/main.tf`
- Create: `terraform/deployments/us-west-2-labcluster/migrations.tf` only for deployment-level address changes not handled by module `moved` blocks
- Modify: `terraform/deployments/us-west-2-labcluster/README.md`

**Interfaces:**
- Produces: lab cluster pinned to `git::https://github.com/zoom-jaredallen/terraform-aws-zoom-node.git?ref=v0.2.0`.
- Consumes: Task 1's authoritative state decision and Task 4's tag.

- [ ] Confirm authoritative state is non-empty for a live environment. If it remains empty, classify the deployment as destroyed and stop before apply.
- [ ] Change only the module source and run `terraform init -upgrade`.
- [ ] Save a plan and use `terraform show -json` plus `jq` to assert zero replacement/deletion actions.
- [ ] For a live state, require expected internal moves from `module.zoom_node.aws_*` to `module.zoom_node.module.{network,node,storage_access}.aws_*` and no node-key changes.
- [ ] Apply only the reviewed saved plan; verify instance, ENI, EIP, NAT, VPC, subnet, bucket, and IAM-profile IDs against the baseline.
- [ ] Preserve existing outputs and update the deployment README with the pinned release and rollback procedure.
- [ ] Commit the deployment migration.

### Task 6: Migrate Tokyo AI Services

**Files:**
- Modify: `terraform/deployments/tokyo-ai-services-explicit-node/{main,variables,outputs}.tf`
- Delete after state adoption: `compute.tf`, `locals.tf`, `network.tf`, `validation.tf`
- Modify: `migrations.tf`, `README.md`

**Interfaces:**
- Produces: two `explicit_nodes` with keys and names `jp01worker1-ap-northeast-1a` and `jp01worker2-ap-northeast-1a`.
- Consumes: existing VPC/subnet, deployment-managed `aws_security_group.ai_services`, and Task 4's module tag.

- [ ] Add the root module in `use_existing` mode with both exact node names, existing private IPs, `g6.12xlarge`/`g6.2xlarge`, current AMI, 500 GB disks, no EIPs, and the existing SG ID.
- [ ] Add moved blocks for each EC2 instance, ENI, and log group to `module.zoom_node.module.node` using the same exact node key.
- [ ] Keep `aws_security_group.ai_services` at its existing address for the first migration; remove only obsolete data/validation resources after state adoption.
- [ ] Save and inspect the plan; permit state moves and in-place tag changes only, with zero instance/ENI replacement.
- [ ] Apply the saved plan and compare instance IDs, ENI IDs, private IPs, SG ID, AMIs, types, and disk sizes to the baseline.
- [ ] Verify output compatibility and Zoom Node registration health.
- [ ] Commit the Tokyo migration.

### Task 7: Migrate GovTech Explicit Nodes

**Files:**
- Modify: `terraform/deployments/govtech-ap-southeast-1-explicit-nodes/{main,variables,outputs}.tf`
- Delete after state adoption: `compute.tf`, `locals.tf`, `network.tf`
- Create: `migrations.tf`
- Modify: `README.md`

**Interfaces:**
- Produces: eight exact `explicit_nodes` retaining the three master and five worker identities.
- Consumes: existing subnet/VPC, SG `sg-0d9070fbb749a5ff4`, instance profile `ZoomNodeS3Access`, and Task 4's module tag.

- [ ] Encode all eight existing node names, IPs, instance types, source/destination-check values, AMI, 500 GB disks, external SG, and external IAM profile.
- [ ] Add 24 moved blocks: EC2, ENI, and log-group state for each exact node key into `module.zoom_node.module.node`.
- [ ] Preserve ENI private-IP ignore changes because kube-vip addresses are managed outside Terraform.
- [ ] Save and inspect the plan; require zero replacement and no new managed SG/IAM resources.
- [ ] Apply the saved plan and compare all instance/ENI IDs, IPs, SG attachments, IAM profile, source/destination checks, AMIs, types, and disks to the baseline.
- [ ] Verify control-plane kube-vip and Zoom registration health.
- [ ] Commit the GovTech migration.

### Task 8: Migrate or Retire Sydney Public Four Node

**Files:**
- Split/modify: `terraform/deployments/sydney-public-four-node-new-vpc/{versions,providers,variables,locals,main,network,outputs,migrations}.tf`
- Modify: `README.md`

**Interfaces:**
- Produces: module-based configuration for four exact Sydney node names and module-managed VPC networking, or an explicitly documented retired deployment.
- Consumes: Task 1's authoritative empty/live state decision and Task 4's module tag.

- [ ] If authoritative state is empty and the environment is intentionally destroyed, refactor configuration without applying and mark it ready for a future fresh deployment; do not manufacture state moves.
- [ ] If live state exists, add moved blocks for VPC, IGW, subnet, route table, route association, each EC2 instance, ENI, EIP, EIP association, and log group. Map EIPs to `<node-key>-eip-0` destinations.
- [ ] Retain `aws_security_group.zoom_node` at the deployment root for the first migration and pass its ID to all explicit nodes.
- [ ] Preserve all four exact hostnames, private IPs, EIPs, AMI, `t3.large` type, 500 GB disks, and management CIDRs.
- [ ] Save and inspect the plan; for a live state require zero replacement, and for an intentionally empty state expect creation but do not apply without a separate deployment approval.
- [ ] For a live migration, apply the saved plan and compare all network and node IDs to the baseline.
- [ ] Commit the migrated or retired Sydney configuration.

### Task 9: Remove the Legacy In-Tree Module and Close Migration Work

**Files:**
- Remove after all consumers migrate: `terraform/modules/zoom-node-aws/`
- Modify: deployment READMEs and repository-level Terraform documentation

**Interfaces:**
- Produces: one supported AWS module implementation and no deployment references to `../../modules/zoom-node-aws`.
- Consumes: successful Tasks 5-8.

- [ ] Add a repository check that fails on references to `modules/zoom-node-aws` or private child-module sources.
- [ ] Run the check and verify it fails before removal.
- [ ] Remove the legacy module only after every live deployment has completed post-apply verification.
- [ ] Run validation for every deployment and confirm all module sources use immutable tags.
- [ ] Archive migration baselines according to the repository's secret/state policy; never commit raw state.
- [ ] Commit legacy module removal.

### Task 10: Remove Deprecated Inputs in v1.0.0

**Files:**
- Modify: `variables.tf`, `locals.tf`, `network.tf`, `security.tf`, `storage.tf`, `validation.tf`, `outputs.tf`
- Delete: `deprecations.tf`
- Modify: tests, examples, `README.md`, `CHANGELOG.md`, `docs/terraform-upgrades.md`

**Interfaces:**
- Produces: v1 facade without the six deprecated compatibility surfaces.
- Consumes: migration evidence that no maintained deployment/example uses them and at least one released minor carried warnings.

- [ ] Add a static repository test proving no maintained configuration uses deprecated names.
- [ ] Run it before cleanup and confirm only compatibility implementation/tests remain.
- [ ] Remove deprecated variables, fallback branches, warnings, and the legacy Hybrid Recording output.
- [ ] Replace compatibility tests with tests that reject removed arguments during configuration loading.
- [ ] Preserve all historical resource `moved` blocks through the v1 major line.
- [ ] Run the complete repository suite and all deployment validation commands.
- [ ] Publish an upgrade guide with exact old-to-new configuration examples and tag `v1.0.0` only after an independent migration review.

---

## Per-Deployment Apply Gate

For every live deployment, use this sequence from its directory:

1. `terraform state pull > .migration/pre-migration.tfstate`
2. `terraform state list > .migration/pre-migration-addresses.txt`
3. Record `aws sts get-caller-identity` and configured region.
4. `terraform init -upgrade`
5. `terraform plan -out=.migration/migration.tfplan`
6. `terraform show -json .migration/migration.tfplan > .migration/migration.json`
7. Reject the plan if jq finds any unapproved replacement or deletion action.
8. Apply exactly `.migration/migration.tfplan`, never a newly generated plan.
9. Pull post-migration state and compare resource IDs and network addresses to the baseline.
10. Run workload health checks before migrating the next deployment.

Rollback is state restoration only when no AWS mutation occurred. After an apply, use a reviewed forward fix; do not blindly push an old state snapshot over newer infrastructure.
