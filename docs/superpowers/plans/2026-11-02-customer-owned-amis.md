# Customer-Owned AMIs Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Require customer-accessible Zoom Node AMIs through a clear channel-aware input and validate them during planning.

**Architecture:** Keep the root module as the compatibility facade. Add customer channel maps ahead of legacy AWS overrides, retain an empty bundled catalog as a future extension point, and perform one exact EC2 image lookup per selected AMI.

**Tech Stack:** Terraform 1.7+, HashiCorp AWS provider 6.x, native Terraform tests.

**Spec:** `docs/superpowers/specs/2026-11-02-customer-owned-amis-design.md`

## Global Constraints

- Preserve every existing AMI override input.
- Do not publish private Zoom AMI IDs in the reusable module.
- Do not add SSM support in this release.
- Validate selected AMIs before creating resources.

## Review Focus

- A channel map must resolve the selected region and channel.
- Exact node and workload overrides must retain precedence.
- Legacy `aws.image_id` and `aws.image_ids` must remain functional.
- Missing customer AMIs must fail with actionable guidance.
- The availability lookup must deduplicate AMIs shared by multiple nodes.

---

### Task 1: Customer AMI Contract

**Files:**
- Modify: `variables.tf`
- Modify: `locals.tf`
- Modify: `validation.tf`
- Modify: `image-catalog.json`
- Test: `tests/images-and-overrides.tftest.hcl`

**Interfaces:**
- Consumes: existing AMI override inputs and `image_channel`.
- Produces: `image_ids.prod` and `image_ids.dev` regional maps plus plan-time selected-image lookups.

- [x] Add failing tests for production/development maps, missing images, compatibility overrides, and deduplicated image lookup.
- [x] Run the focused tests and confirm failures describe the missing contract.
- [x] Implement the new input, precedence, empty catalog, and EC2 AMI data lookups.
- [x] Run the focused and complete native test suites.

### Task 2: Customer Onboarding Documentation

**Files:**
- Modify: `README.md`
- Modify: `CHANGELOG.md`
- Create: `examples/customer-ami-catalog/README.md`
- Create: `examples/customer-ami-catalog/main.tf`
- Create: `examples/customer-ami-catalog/variables.tf`
- Create: `examples/customer-ami-catalog/terraform.tfvars.example`
- Create: `examples/customer-ami-catalog/versions.tf`

**Interfaces:**
- Consumes: Task 1's `image_ids` contract.
- Produces: a copyable customer configuration and upgrade guidance.

- [x] Add documentation contract assertions before changing documentation.
- [x] Document private AMI visibility, regional ownership, precedence, and upgrade impact.
- [x] Add and validate the focused example.
- [x] Run formatting, validation, linting, security scans, and documentation checks.

