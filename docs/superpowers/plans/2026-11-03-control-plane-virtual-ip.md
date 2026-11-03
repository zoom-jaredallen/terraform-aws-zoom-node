# Control Plane Virtual IP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a provider-neutral control-plane VIP input backed by an AWS master ENI secondary address.

**Architecture:** Normalize the portable endpoint at the root facade, split guest bootstrap addresses from provider ENI addresses, and pass only the ENI list into the AWS node module. Preserve the existing ENI lifecycle contract and reserve assignment-mode extensibility for a future load-balancer backend.

**Tech Stack:** Terraform 1.7+, HashiCorp AWS provider 6.x, native Terraform tests.

**Spec:** `docs/superpowers/specs/2026-11-03-control-plane-virtual-ip-design.md`

## Global Constraints

- Default behavior must remain unchanged when the input is null.
- The VIP must never appear in cloud-init or Elastic IP records.
- Existing ENI private-IP ignore behavior must remain intact.
- This release supports only `assignment_mode = "node"`.

## Review Focus

- Unknown or non-master owner keys must fail before resource creation.
- The VIP must be inside the owner's selected subnet and avoid reserved addresses.
- The VIP must not overlap any generated or explicit node address.
- Source/destination checking must be disabled on the owner.
- Existing deployments without the input must retain their current plans.

---

### Task 1: Portable Contract And Validation

**Files:**
- Modify: `variables.tf`
- Modify: `validation.tf`
- Test: `tests/networking.tftest.hcl`

- [ ] Add failing plan tests for valid assignment, unsupported mode, invalid owner role, enabled source/destination checking, subnet mismatch, reserved address, and collision.
- [ ] Add the nullable `control_plane_virtual_ip` object with `address`, optional `assignment_mode`, and `owner_node_key`.
- [ ] Normalize and validate the input without provider-specific fields.
- [ ] Run the focused networking tests.

### Task 2: Split Bootstrap And ENI Addresses

**Files:**
- Modify: `compute.tf`
- Modify: `main.tf`
- Modify: `outputs.tf`
- Modify: `modules/node/variables.tf`
- Test: `tests/networking.tftest.hcl`

- [ ] Add failing assertions that the owner ENI includes the VIP while cloud-init and EIP records exclude it.
- [ ] Retain `node_private_ips` as bootstrap addresses and derive `node_eni_private_ips` with the owner VIP appended.
- [ ] Pass ENI addresses to the node module and expose normalized endpoint details.
- [ ] Run focused tests and the module extraction contract.

### Task 3: Documentation And Upgrade Safety

**Files:**
- Modify: `README.md`
- Modify: `docs/networking.md`
- Modify: `docs/terraform-upgrades.md`
- Modify: `CHANGELOG.md`

- [ ] Document creation behavior and the explicit replacement procedure for existing master ENIs.
- [ ] Document the current kube-vip failover limitation and future load-balancer mode.
- [ ] Regenerate module documentation and run the complete repository gate.
