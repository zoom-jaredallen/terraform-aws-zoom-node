# Native Contract Coverage Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Cover every workload and major deployment/configuration branch with native mocked Terraform contract tests.

**Architecture:** Split contracts by domain into independent `.tftest.hcl` files and enforce the requested coverage with a run-name manifest check. Keep all tests plan-only and leave production resources unchanged.

**Tech Stack:** Terraform 1.7+ test framework, mocked AWS and Random providers, Bash repository checks.

**Spec:** `docs/superpowers/specs/2026-10-27-native-contract-coverage-design.md`

## Global Constraints

- Do not create real AWS resources.
- Do not change the public module interface or production Terraform behavior.
- Each test file must run independently through `terraform test -filter`.
- Keep test credentials and identifiers synthetic.

## Review Focus

- Catalog defaults must be asserted per workload, not merely counted.
- Existing-VPC data mocks must supply usable VPC and subnet CIDRs.
- NAT assertions must prove both private routing and public NAT placement.
- NIC tests must establish override precedence and rendered cloud-init values.
- Exhaustion tests must fail through the module validation contract for the intended reason.

---

### Task 1: Coverage Gate

**Files:**
- Create: `scripts/check-test-contract-coverage.sh`
- Modify: `scripts/check-repository.sh`

- [x] Add a required run-name manifest in the coverage script.
- [x] Run the script and verify it fails because the new contracts do not exist.
- [x] Add the script to the repository gate.

### Task 2: Workload Contracts

**Files:**
- Create: `tests/workloads.tftest.hcl`

- [x] Add independent plan runs for all six workload types.
- [x] Assert node counts, instance types, storage, and private/public IP defaults.
- [x] Run the workload file and verify every run passes.

### Task 3: Network Contracts

**Files:**
- Create: `tests/networking.tftest.hcl`

- [x] Cover create-new single AZ and dual AZ placement.
- [x] Cover existing VPC/subnet selection with mocked data sources.
- [x] Cover a public control-plane plus private worker topology using NAT.
- [x] Cover global Spot selection and IP overlap/exhaustion failures.
- [x] Run the networking file and verify every run passes.

### Task 4: Image, NIC, and Per-Node Contracts

**Files:**
- Create: `tests/images-and-overrides.tftest.hcl`

- [x] Cover production and development AMI catalog lookup.
- [x] Cover catalog NIC mapping and exact, family, and global overrides.
- [x] Cover stable-key AMI and source/destination-check overrides.
- [x] Run the image and override file and verify every run passes.

### Task 5: Storage-Mode Contracts

**Files:**
- Create: `tests/storage-modes.tftest.hcl`

- [x] Cover Hybrid Recording create-new and existing S3 modes.
- [x] Cover advanced S3 access with one managed and one existing bucket.
- [x] Assert IAM policies and bucket ownership behavior.
- [x] Run the storage file and verify every run passes.

### Task 6: Full Verification and Documentation

**Files:**
- Modify: `CHANGELOG.md`
- Modify: `docs/terraform-best-practices-review.md`

- [x] Mark expanded native coverage in the changelog and review scorecard.
- [x] Run the coverage gate and full repository check.
- [x] Review the final diff for production-code changes and sensitive values.

