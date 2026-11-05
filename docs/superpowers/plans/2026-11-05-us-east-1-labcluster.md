# US East Lab Cluster Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a validated, non-applied Terraform deployment root for the requested nine-node `us-east-1` test environment.

**Architecture:** Reuse the maintained deployment-root convention and in-repository module until the managed-EIP update fix is released. Resolve region-local AMIs from the shared deployment catalog, retain CPU nodes in `us-east-1a`, and give the GPU a separately selectable private subnet after `us-east-1a` reported insufficient capacity.

**Tech Stack:** Terraform, AWS provider, `terraform-aws-zoom-node` v0.4.1, AWS CLI.

**Spec:** `docs/superpowers/specs/2026-11-05-us-east-1-labcluster-design.md`

## Global Constraints

- Do not create AWS resources.
- Do not commit registration codes, credentials, state, or saved plans.
- Use the development AMI only for Kubernetes masters.
- Use On-Demand instances; changing GPU placement must not replace successful CPU nodes.

## Review Focus

- Confirm the two AMI IDs resolve in `us-east-1` and report their pending state without attempting an apply.
- Confirm all nine nodes resolve to the requested image channel and instance count.
- Confirm the `g6.12xlarge` cloud-init interface resolves to `enp39s0`.
- Confirm private workers have NAT-backed startup connectivity.
- Confirm the example variable file contains no live secrets.

---

### Task 1: Regional image catalog

**Files:**
- Modify: `deployments/aws-ami-catalog.json`

- [ ] Add the supplied `us-east-1` production and development AMI IDs.
- [ ] Validate the catalog as JSON.

### Task 2: Deployment root

**Files:**
- Create: `deployments/us-east-1-labcluster/versions.tf`
- Create: `deployments/us-east-1-labcluster/providers.tf`
- Create: `deployments/us-east-1-labcluster/variables.tf`
- Create: `deployments/us-east-1-labcluster/locals.tf`
- Create: `deployments/us-east-1-labcluster/main.tf`
- Create: `deployments/us-east-1-labcluster/outputs.tf`
- Create: `deployments/us-east-1-labcluster/terraform.tfvars.example`
- Create: `deployments/us-east-1-labcluster/README.md`

- [ ] Add the conventional Terraform files using the maintained deployment pattern.
- [ ] Configure one Meetings node, three development-image masters, four production-image workers, and one production-image GPU worker.
- [ ] Configure one new VPC/AZ, NAT-backed private nodes, generated password, IAM/S3 access, and G6 NIC mapping.
- [ ] Document initialization, local registration input, optional preflight, plan, and apply commands.

### Task 3: Repository integration and verification

**Files:**
- Modify: `deployments/README.md`
- Generate: `deployments/us-east-1-labcluster/.terraform.lock.hcl`

- [ ] Add the maintained deployment to the deployment index.
- [ ] Run Terraform formatting.
- [ ] Initialize the root without a backend and generate its lockfile.
- [ ] Run `terraform validate` and repository deployment checks.
- [ ] Verify no local secret or state artifact is tracked.

