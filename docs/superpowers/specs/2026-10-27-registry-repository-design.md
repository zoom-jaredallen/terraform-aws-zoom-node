# Terraform AWS Zoom Node Registry Repository Design

## Intent

Publish the existing AWS-native Zoom Node module as a dedicated, public Terraform Registry repository. The repository gives colleagues and customers an immutable, documented module source without exposing CloudFormation code, account-specific deployments, credentials, state, or unrelated project history.

## Selected Approach

Create a clean repository at `zoom-jaredallen/terraform-aws-zoom-node` rather than filtering the mixed CloudFormation repository history. The reusable module becomes the repository root, the three generic examples remain under `examples/`, and the first release is tagged `v0.1.0`.

Alternatives considered:

- Preserve subtree history with `git filter-repo`: rejected because the module has depended on repository-level tests and documentation, producing a noisy and incomplete history after filtering.
- Publish the existing monorepo: rejected because the Terraform Registry expects the reusable module at the repository root and this repository contains multiple unrelated infrastructure products.

## Public Contract

- Preserve all current module inputs, outputs, resource addresses, catalogs, tests, and the upgrade contract.
- Preserve Terraform `>= 1.7.0`, AWS provider `>= 6.0`, and Random provider `>= 3.6` requirements.
- Keep customer provider configuration in root modules; the child module contains no provider configuration blocks.
- Keep `moved.tf` and retain future moved blocks throughout a major release.

## Repository Contents

- Root module Terraform files, catalogs, templates, native Terraform tests, and generated `README.md`.
- Generic new-VPC, existing-VPC, and smoke examples using `source = "../.."`.
- Apache License 2.0, changelog, contribution and security guidance.
- GitHub Actions for formatting, generated documentation, TFLint, validation, native tests, example validation, and Trivy scanning.
- Release and Registry publishing guidance, including immutable semantic-version tags.

## Safety

- Do not copy `.env`, Terraform state, plan files, `.terraform/`, local variable files, credentials, or account-specific deployment roots.
- Do not copy the child module lock file; executable examples retain reviewed lock files.
- Scan the complete repository for secrets and sensitive artifacts before publishing.

## Publication

Create the public GitHub repository under `zoom-jaredallen`, push `main`, create annotated tag `v0.1.0`, publish the matching GitHub release, and enable private vulnerability reporting when supported.
