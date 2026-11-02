# EC2 Capacity Failure Handling Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bound AWS provider retries, configure EC2 creation timeouts, validate exact-AZ instance offerings, and provide an optional Capacity Manager score preflight that automatically reads resolved capacity requirements from a saved Terraform plan.

**Architecture:** Executable roots own AWS provider retry settings. The reusable module resolves per-node EC2 timeouts, performs static AZ offering validation, and publishes a nonsensitive capacity manifest. A standalone AWS CLI script extracts that manifest from a saved plan and performs volatile Capacity Manager checks without making Terraform plans depend on AWS Support tier or live scores. Explicit CLI arguments remain available for ad hoc checks.

**Tech Stack:** Terraform 1.7+, HashiCorp AWS provider 6.x, Bash, AWS CLI v2, jq, native Terraform tests.

**Spec:** `docs/superpowers/specs/2026-11-02-capacity-failure-handling-design.md`

## Global Constraints

- Preserve all Terraform resource addresses and stable node keys.
- Default module create timeout remains `10m`; maintained provider roots default to five retries.
- Capacity preflight is optional and never runs implicitly from Terraform.
- Do not enable Capacity Manager or create Capacity Reservations.
- Do not persist or publish Capacity Manager score responses.
- Never print or retain complete Terraform plan JSON; it can contain registration codes, passwords, cloud-init, and other sensitive values.

## Review Focus

- Provider retries must be configured only in executable roots, never inside child modules.
- Timeout precedence must be stable-node override, then group/explicit value, then global default.
- Invalid duration strings and unknown node override keys must fail during planning.
- AZ offering checks must use each node's resolved subnet AZ, not only the deployment's first AZ.
- Preflight prerequisite failures must be distinguishable from a valid `low` score.

---

### Task 1: Native Timeout Contract

**Files:**
- Modify: `variables.tf`
- Modify: `locals.tf`
- Modify: `validation.tf`
- Modify: `modules/node/variables.tf`
- Modify: `modules/node/main.tf`
- Modify: `modules/node/outputs.tf`
- Modify: `outputs.tf`
- Test: `tests/images-and-overrides.tftest.hcl`
- Test: `tests/explicit-nodes.tftest.hcl`

**Interfaces:**
- Consumes: stable node records and AWS configuration.
- Produces: resolved `instance_create_timeout` on every node record, `aws_instance.timeouts.create`, and a nonsensitive `capacity_preflight_requests` output.

- [ ] Add failing native tests for the `10m` default, group override, explicit-node override, stable-key override precedence, malformed duration, and unknown stable key.
- [ ] Run the focused tests and confirm they fail because timeout inputs do not exist.
- [ ] Add `aws.instance_create_timeout`, `aws.node_instance_create_timeouts`, and optional group/explicit timeout attributes.
- [ ] Normalize timeout precedence into `local.node_records` and propagate it through the private node module.
- [ ] Apply the resolved value to the EC2 resource `timeouts.create` and expose it through the private test contract.
- [ ] Add validation for duration syntax and unknown stable node keys.
- [ ] Add a grouped `capacity_preflight_requests` output containing exactly region, Availability Zone, instance type, market type, and instance count; assert that no bootstrap, networking identifier, AMI, or credential field is present.
- [ ] Run focused tests, then the full native Terraform suite.

### Task 2: Exact-AZ Offering Validation

**Files:**
- Modify: `locals.tf`
- Modify: `validation.tf`
- Test: `tests/networking.tftest.hcl`
- Test: `tests/workloads.tftest.hcl`

**Interfaces:**
- Consumes: resolved node subnet IDs/AZs and instance types.
- Produces: deduplicated `<instance-type>:<availability-zone>` offering checks.

- [ ] Add failing tests for a type offered in one selected AZ and absent from another.
- [ ] Add a test proving duplicate nodes in one type/AZ produce one lookup.
- [ ] Replace region-level offering queries with `location_type = "availability-zone"` queries keyed by resolved type/AZ pairs.
- [ ] Emit an actionable validation error containing both instance type and AZ.
- [ ] Run networking, workload, and complete native test suites.

### Task 3: Provider Retry Controls In Standalone Examples

**Files:**
- Modify: `examples/aws-new-vpc/providers.tf`
- Modify: `examples/aws-new-vpc/variables.tf`
- Modify: `examples/aws-new-vpc/terraform.tfvars.example`
- Modify: `examples/aws-existing-vpc/providers.tf`
- Modify: `examples/aws-existing-vpc/variables.tf`
- Modify: `examples/aws-existing-vpc/terraform.tfvars.example`
- Modify: `examples/aws-smoke-single-node/providers.tf`
- Modify: `examples/aws-smoke-single-node/variables.tf`
- Modify: `examples/aws-smoke-single-node/terraform.tfvars.example`
- Modify: `examples/customer-ami-catalog/providers.tf`
- Modify: `examples/customer-ami-catalog/variables.tf`
- Modify: `examples/customer-ami-catalog/terraform.tfvars.example`
- Modify: each example root `outputs.tf`

**Interfaces:**
- Consumes: root variables `aws_max_retries`, `aws_retry_mode`, and the module capacity manifest.
- Produces: provider configuration with defaults `5` and `standard`, plus a forwarded `capacity_preflight_requests` output.

- [ ] Add repository contract checks requiring both provider settings in every example root.
- [ ] Add validated variables and example values to every root.
- [ ] Configure each provider without changing credentials or region behavior.
- [ ] Forward `module.zoom_node.capacity_preflight_requests` unchanged from every maintained example root.
- [ ] Initialize read-only lockfiles, validate, and lint every example.

### Task 4: Capacity Manager Preflight Script

**Files:**
- Create: `scripts/check-ec2-capacity.sh`
- Create: `scripts/test-check-ec2-capacity.sh`
- Modify: `scripts/check-repository.sh`

**Interfaces:**
- Consumes: either a saved Terraform plan or explicit target region, optional Capacity Manager home region, market, capacity, AZ names, instance types, optional threshold and output mode.
- Produces: human table or JSON scores and documented exit codes `0`, `2`, `3`, `64`.

- [ ] Create fake `terraform`, `aws`, and `jq` fixtures that record arguments and return deterministic responses.
- [ ] Add failing tests for saved-plan extraction, grouped instance counts, mixed on-demand and Spot requests, AZ-name translation, a distinct Capacity Manager home region, high/medium/low table output, aggregate output, repeated types/AZs, and JSON output.
- [ ] Add failing tests for threshold failure, disabled Capacity Manager, unsupported support plan, access denied, invalid CLI input, and malformed AWS responses.
- [ ] Add tests proving plan mode and manual mode are mutually exclusive and rejecting a missing, malformed, or sensitive-field capacity manifest.
- [ ] Add fake secrets elsewhere in the plan JSON and prove they never appear in stdout, stderr, temporary files, or retained artifacts.
- [ ] Implement strict Bash parsing with `set -euo pipefail`, permission-restricted temporary files, cleanup traps, dependency checks, and no credential/output persistence.
- [ ] Implement `terraform show -json` streaming extraction of `.planned_values.outputs.capacity_preflight_requests.value`, schema validation, and secure disposal of the complete plan stream.
- [ ] Implement account identity check, Capacity Manager status check, AZ ID translation, score request, table rendering, JSON rendering, and threshold evaluation.
- [ ] Group manifest entries by market type and instance count before invoking the AWS API; require `--capacity-manager-region` for multi-region manifests.
- [ ] Add the script test to `scripts/check-repository.sh` and run it without live AWS access.

### Task 5: Documentation And Upgrade Safety

**Files:**
- Modify: `README.md`
- Modify: `docs/terraform-upgrades.md`
- Modify: `CHANGELOG.md`
- Modify: example READMEs under `examples/`

**Interfaces:**
- Consumes: Tasks 1-4 interfaces.
- Produces: operator instructions for retries, timeouts, scores, IAM, support-plan limitations, and remediation.

- [ ] Document the provider/module ownership boundary and equivalent AWS environment variables.
- [ ] Document that AZ offering validation and Capacity Manager scores do not guarantee physical capacity.
- [ ] Make saved-plan mode the primary documented workflow, retain copyable manual On-Demand and Spot commands, and explain score/exit-code semantics.
- [ ] Warn that saved plan files can contain secrets and document secure storage and deletion expectations.
- [ ] Document minimum IAM actions, Capacity Manager enablement, Unified Operations requirement, and the prohibition on sharing score results.
- [ ] Document recommended actions: high means proceed, medium/low means add AZ/type flexibility or retry later.
- [ ] Regenerate terraform-docs and run documentation checks.

### Task 6: Publish Module Release And Migrate Maintained Roots

**Files:**
- Modify in `zoom-node-cloudformation`: every `terraform/**/providers.tf`
- Modify in `zoom-node-cloudformation`: corresponding `variables.tf` and `terraform.tfvars.example` files
- Modify: `terraform/deployments/us-west-2-labcluster/main.tf`
- Modify: `terraform/deployments/us-west-2-labcluster/variables.tf`
- Modify: `terraform/deployments/us-west-2-labcluster/terraform.tfvars.example`
- Modify: deployment packaging and contract tests
- Modify in `zoom-node-cloudformation`: maintained deployment `outputs.tf` files

**Interfaces:**
- Consumes: immutable `terraform-aws-zoom-node` release `v0.4.0`.
- Produces: maintained roots with bounded provider retries and explicit AI timeout settings.

- [ ] Run the standalone repository gate and review the complete diff.
- [ ] Commit the combined customer-AMI and capacity-handling work, tag `v0.4.0`, push, and create a GitHub release without publishing to the Terraform Registry.
- [ ] Update all maintained provider roots with `aws_max_retries = 5` and `aws_retry_mode = "standard"` defaults.
- [ ] Forward `capacity_preflight_requests` from every maintained deployment root so automatic plan mode works consistently.
- [ ] Upgrade deployment module sources to `v0.4.0` only after supplying each deployment's existing customer AMIs through `image_ids` or retained exact overrides.
- [ ] Set the US West lab AI group create timeout to `5m`; retain `10m` elsewhere unless explicitly customized.
- [ ] Run saved plans for stateful deployments and stop if any unchanged node, ENI, AMI, IP, or EIP is replaced.
- [ ] Run both repository gates, commit deployment changes, and leave infrastructure unapplied until separately approved.

