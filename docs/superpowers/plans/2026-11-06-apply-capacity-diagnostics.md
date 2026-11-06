# Terraform Apply Capacity Diagnostics Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a guarded Terraform apply wrapper that blocks predictable capacity failures and explains AWS runtime failures clearly.

**Architecture:** A Bash wrapper composes the existing Capacity Manager preflight with `terraform apply`, without changing module resources or provider behavior. Shell contract tests use fake Terraform and preflight executables to exercise exit codes and diagnostics deterministically.

**Tech Stack:** Bash 3.2, Terraform CLI, existing AWS Capacity Manager preflight, repository shell-test harness.

**Spec:** `docs/superpowers/specs/2026-11-06-apply-capacity-diagnostics-design.md`

## Global Constraints

- Preserve Terraform's original output and apply exit status.
- Never automatically alter placement or retry a different plan.
- Keep Capacity Manager optional through an explicit skip.
- Do not expose plan or credential contents in diagnostics.

## Review Focus

- Low score with and without the explicit override.
- Capacity Manager unavailable versus intentionally skipped.
- Diagnostic parsing when optional instance type, AZ, alternatives, or resource address fields are absent.
- Terraform success, known AWS failure, and unknown Terraform failure exit statuses.
- Temporary file cleanup and argument forwarding.

---

### Task 1: Guarded apply contract

**Files:**
- Create: `scripts/test-apply-with-diagnostics.sh`
- Create: `scripts/apply-with-diagnostics.sh`
- Modify: `scripts/check-repository.sh`

**Interfaces:**
- Consumes: `check-ec2-capacity.sh --terraform-plan FILE --minimum-score SCORE`
- Produces: `apply-with-diagnostics.sh --terraform-plan FILE` with preflight controls and classified diagnostics.

- [x] Write failing shell tests for argument validation, high/low/unavailable/skipped preflight, override behavior, successful apply, known AWS diagnostics, unknown failures, exit-status preservation, and temporary cleanup.
- [x] Run `scripts/test-apply-with-diagnostics.sh` and confirm it fails because the wrapper is absent.
- [x] Implement the minimal Bash wrapper and add the test to `scripts/check-repository.sh`.
- [x] Run the focused shell tests and confirm all cases pass.

### Task 2: Operator documentation

**Files:**
- Modify: `README.md`
- Modify: `docs/getting-started.md`
- Modify: `docs/troubleshooting.md`

**Interfaces:**
- Consumes: the Task 1 CLI.
- Produces: documented guarded apply and recovery workflows.

- [x] Document the default guarded workflow, explicit low-capacity override, explicit preflight skip, recognized errors, and non-transactional apply warning.
- [x] Run formatting/documentation checks and the complete repository gate.

