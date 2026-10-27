# Terraform AWS Zoom Node Registry Repository Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create and publish a Registry-ready `terraform-aws-zoom-node` repository from the proven AWS module.

**Architecture:** Promote the current child module to the new repository root and retain generic examples as child directories. Add repository-level packaging, CI, licensing, security, and release metadata without changing the Terraform module contract.

**Tech Stack:** Terraform 1.7+, HashiCorp AWS provider 6.x, Random provider 3.6+, terraform-docs, TFLint, Trivy, GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-10-27-registry-repository-design.md`

## Global Constraints

- Repository: public `zoom-jaredallen/terraform-aws-zoom-node`.
- License: Apache License 2.0.
- Initial release: `v0.1.0`.
- Preserve the current public Terraform API and resource addresses.
- Exclude credentials, state, plan files, `.terraform/`, local variables, and account-specific deployments.

## Review Focus

- Root module paths must not retain monorepo-relative references.
- Examples must resolve the root module through `source = "../.."`.
- CI must validate both the root module and every example.
- Generated documentation must be reproducible from the root module.
- Publication must contain no state, credentials, or ignored local artifacts.

---

### Task 1: Extract The Module And Examples

**Files:**
- Create: root `*.tf`, catalogs, `templates/`, `tests/`, and `examples/`
- Create: `.gitignore`

- [ ] Copy the reusable module into the repository root, excluding its generated lock directory and lock file.
- [ ] Copy the three generic examples and change each module source to `../..`.
- [ ] Add ignore rules for credentials, state, plans, local variables, and Terraform working directories.
- [ ] Run `terraform fmt -check -recursive .` and `terraform validate`.

### Task 2: Add Registry And Project Metadata

**Files:**
- Create: `LICENSE`, `CHANGELOG.md`, `CONTRIBUTING.md`, `SECURITY.md`
- Modify: `README.md`
- Create: `docs/terraform-upgrades.md`, `docs/releasing.md`

- [ ] Add Apache License 2.0 and public contribution/security guidance.
- [ ] Adapt the generated README introduction, examples, source address, and migration notes for the dedicated repository.
- [ ] Add initial `v0.1.0` changelog and release procedure.
- [ ] Generate and verify terraform-docs output at the repository root.

### Task 3: Add Repository CI And Tests

**Files:**
- Create: `.github/workflows/terraform.yml`
- Create: `.terraform-docs.yml`, `.tflint.hcl`, `.trivyignore.yaml`
- Create: `scripts/check-repository.sh`

- [ ] Add CI checks for format, docs, TFLint, root validation, native tests, example validation, and Trivy.
- [ ] Add a local check script that runs the same gates.
- [ ] Run native Terraform tests and validate all examples using their committed lock files.
- [ ] Scan the repository for secrets and excluded artifacts.

### Task 4: Publish Version 0.1.0

**Files:**
- Create: Git repository metadata and GitHub repository.

- [ ] Initialize `main`, commit the complete clean repository, and confirm only intended files are tracked.
- [ ] Create public `zoom-jaredallen/terraform-aws-zoom-node` with its Registry-facing description.
- [ ] Push `main`, create and push annotated tag `v0.1.0`, and publish matching release notes.
- [ ] Enable private vulnerability reporting and verify the repository and tag URLs.
