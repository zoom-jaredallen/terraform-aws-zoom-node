# Paris Lab Cluster Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a validated, unapplied Paris clone of the US West lab deployment using region-local encrypted Zoom Node AMIs.

**Architecture:** Copy both account-owned AMIs into `eu-west-3`, register them in the shared deployment catalog, and create an independent conventional Terraform root. Keep the topology compatible with the existing module while using Paris-specific networking, naming, and state.

**Tech Stack:** Terraform, AWS provider, AWS CLI, JSON AMI catalog, Bash validation scripts.

**Spec:** `docs/superpowers/specs/2026-11-03-paris-labcluster-design.md`

## Global Constraints

- Pin the root to `v0.4.1`.
- Use `eu-west-3b`, VPC `10.30.0.0/16`, and bucket `zoomnode-paris-labcluster-s3`.
- Encrypt copied AMIs with `alias/aws/ebs`.
- Never copy state, secrets, plans, or Terraform working directories.
- Do not apply the deployment or create EC2 instances.

## Review Focus

- AMI copy completes but remains pending or failed: wait and validate `available` before catalog insertion.
- Destination AMI is encrypted with an unexpected key: assert encryption and destination ownership.
- A source-local artifact is copied: verify the new root contains only committed configuration and tests.
- An inherited instance type is unavailable in `eu-west-3b`: validate exact-AZ offerings during plan.
- The new root accidentally shares US West state or CIDRs: assert independent files and `10.30.0.0/16` configuration.

---

### Task 1: Copy and validate regional AMIs

**Files:**
- Modify: `deployments/aws-ami-catalog.json`

**Interfaces:**
- Consumes: US West production and development AMI IDs from the deployment catalog.
- Produces: available `eu-west-3` AMI IDs under the existing `prod` and `dev` maps.

- [ ] Copy both AMIs with region-specific names and `alias/aws/ebs` encryption.
- [ ] Wait for both destination images to become available.
- [ ] Verify owner, architecture, state, encryption, and backing snapshot key.
- [ ] Add the IDs to `deployments/aws-ami-catalog.json` and validate it with `jq`.

### Task 2: Create the Paris deployment root

**Files:**
- Create: `deployments/eu-west-3-paris-labcluster/{README.md,locals.tf,main.tf,outputs.tf,providers.tf,terraform.tfvars.example,variables.tf,versions.tf}`
- Create: `deployments/eu-west-3-paris-labcluster/tests/ami-catalog.tftest.hcl`
- Modify: `deployments/README.md`

**Interfaces:**
- Consumes: Paris AMI catalog entries from Task 1 and module release `v0.4.1`.
- Produces: an independent Paris Terraform root with the approved topology.

- [ ] Copy only the conventional source and test structure from the US West deployment.
- [ ] Replace regional naming, CIDRs, AZs, bucket, and documentation with approved Paris values.
- [ ] Add the deployment to the maintained deployment index.
- [ ] Assert no local state, plans, secrets, or `.terraform` paths are present.

### Task 3: Validate without creating infrastructure

**Files:**
- Test: `deployments/eu-west-3-paris-labcluster/tests/ami-catalog.tftest.hcl`

**Interfaces:**
- Consumes: completed Paris root and available copied AMIs.
- Produces: validation evidence and a reviewed create-only plan.

- [ ] Run Terraform formatting, initialization, validation, and native tests.
- [ ] Run a plan with a placeholder registration code and confirm it proposes only new Paris resources.
- [ ] Run the capacity preflight and record its advisory score.
- [ ] Run repository artifact and diff checks, confirming no infrastructure was applied.
