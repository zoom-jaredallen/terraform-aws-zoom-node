# G5 AI Workers Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Run both US West lab AI workers on `g5.12xlarge` with four NVIDIA A10G GPUs each while preserving centralized production/development AMI selection and the Kubernetes master's Dev AMI.

**Architecture:** Add `g5.12xlarge` to the standalone module's exact instance and AI workload catalogs, release it immutably, then update only the lab deployment to consume that release. Keep AMI IDs in `image-catalog.json`; the master selects `dev` and all other groups select `prod` through `image_channel`.

**Tech Stack:** Terraform 1.7+, AWS provider 6.x, native Terraform tests, Python repository contract tests, AWS EC2 and Service Quotas APIs.

**Spec:** Approved scope in the 2026-11-02 conversation.

## Global Constraints

- Both AI workers use `g5.12xlarge`, On-Demand, 500 GB EBS, one private IP, and no EIP.
- Kubernetes master keeps `image_channel = "dev"`; production remains the default elsewhere.
- `us-west-2` AMIs remain centralized in `image-catalog.json`: prod `ami-0d693e77e13176e99`, dev `ami-08254730bfaf2cb38`.
- The dedicated AI subnet must use a G5-supported AZ; `us-west-2d` is not supported.
- No AWS resources are applied as part of this change.

## Review Focus

- Missing G5 NIC mapping must fail tests rather than reach cloud-init with an empty interface.
- The master must resolve the Dev AMI while AI workers resolve the production AMI.
- The AI subnet AZ must be one where `g5.12xlarge` is offered.
- Existing stateful deployments must remain pinned and unaffected by the lab-only module upgrade.
- The module source gate must allow independently pinned immutable semantic versions without allowing branches.

---

### Task 1: Add G5 module support

**Files:**
- Modify: `instance-catalog.json`
- Modify: `workload-catalog.json`
- Modify: `tests/workloads.tftest.hcl`
- Modify: `README.md`
- Modify: `CHANGELOG.md`

**Interfaces:**
- Produces: `g5.12xlarge` exact NIC mapping and AI Services support in the reusable module.

- [ ] Add failing catalog and native Terraform assertions for `g5.12xlarge`.
- [ ] Run the focused tests and confirm failure.
- [ ] Add `g5.12xlarge` with the verified appliance NIC mapping and AI supported-type entry.
- [ ] Update module documentation and changelog.
- [ ] Run module format, validation, TFLint, Terraform tests, and repository checks.
- [ ] Commit the module changes.

### Task 2: Publish immutable module release

**Files:**
- Modify: module Git history and release metadata.

**Interfaces:**
- Consumes: Task 1 module commit.
- Produces: immutable Git source tag `v0.3.0`.

- [ ] Push the module commit.
- [ ] Create and push annotated tag `v0.3.0`.
- [ ] Create the matching GitHub release without publishing to the Terraform Registry.
- [ ] Verify the tag resolves remotely.

### Task 3: Update the US West lab deployment

**Files:**
- Modify: `terraform/deployments/us-west-2-labcluster/main.tf`
- Modify: `terraform/deployments/us-west-2-labcluster/variables.tf`
- Modify: `terraform/deployments/us-west-2-labcluster/terraform.tfvars.example`
- Modify: `terraform/deployments/us-west-2-labcluster/README.md`
- Modify: `scripts/check-terraform-module-sources.sh`
- Modify: `tests/test_us_west_2_labcluster_deployment.py`
- Modify: `tests/test_terraform_packaging.py`

**Interfaces:**
- Consumes: immutable module release `v0.3.0`.
- Produces: two `g5.12xlarge` AI workers and one Dev-channel Kubernetes master in the lab plan.

- [ ] Add failing repository tests for `g5.12xlarge`, the supported AZ, Dev master image resolution, and immutable independent source tags.
- [ ] Run focused tests and confirm failure.
- [ ] Pin the lab root to `v0.3.0`, change AI type to `g5.12xlarge`, and change the dedicated AI AZ to `us-west-2b`.
- [ ] Generalize the source gate to accept immutable `vMAJOR.MINOR.PATCH` tags while rejecting branches and local/private module paths.
- [ ] Update deployment documentation and examples.
- [ ] Initialize and validate the lab root, then create a read-only plan and inspect its image IDs, instance types, AZ, and replacement counts.
- [ ] Run all repository tests and commit the deployment changes.

### Task 4: Final verification

**Files:**
- Verify both repositories only.

**Interfaces:**
- Consumes: Tasks 1-3.
- Produces: reproducible evidence that the module and deployment remain valid.

- [ ] Run full module repository checks.
- [ ] Run source gate, format, pytest, Terraform validate, and TFLint in the deployment repository.
- [ ] Confirm no secrets or local variable files are staged.
- [ ] Confirm the deployment repository is not pushed unless explicitly requested.
