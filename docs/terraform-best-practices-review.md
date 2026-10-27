# Terraform Module Best-Practices Review

Review date: 2026-10-27

## Scope and Method

This review assesses `terraform-aws-zoom-node` as a reusable AWS child module. It compares the repository against current first-party Terraform guidance, GitHub Actions security guidance, and conventions used by established AWS Terraform modules.

Primary references:

- [HashiCorp standard module structure](https://developer.hashicorp.com/terraform/language/modules/develop/structure)
- [HashiCorp Terraform style guide](https://developer.hashicorp.com/terraform/language/style)
- [HashiCorp providers within modules](https://developer.hashicorp.com/terraform/language/modules/develop/providers)
- [HashiCorp version constraint guidance](https://developer.hashicorp.com/terraform/language/expressions/version-constraints)
- [HashiCorp module composition guidance](https://developer.hashicorp.com/terraform/language/modules/develop/composition)
- [HashiCorp native Terraform test documentation](https://developer.hashicorp.com/terraform/cli/commands/test)
- [HashiCorp validation guidance](https://developer.hashicorp.com/terraform/language/validate)
- [HashiCorp module refactoring guidance](https://developer.hashicorp.com/terraform/language/modules/develop/refactoring)
- [HashiCorp sensitive and ephemeral data guidance](https://developer.hashicorp.com/terraform/language/manage-sensitive-data)
- [GitHub Actions secure-use guidance](https://docs.github.com/en/actions/reference/security/secure-use)

## Overall Score

**7.9/10**

The module has a strong foundation: typed interfaces, minimum-only provider constraints, no embedded provider configuration, stable resource keys, extensive plan-time validation, native tests, generated documentation, security scans, an Apache license, and an explicit upgrade contract. It is suitable for controlled internal use and lab deployments today.

The score is held back primarily by the absence of real AWS apply tests, mutable GitHub Actions dependencies, examples that use local module paths, secrets persisted through EC2 user data, and a public interface whose complexity is beginning to exceed what one root module can comfortably own.

## Scorecard

| Criterion | Score | Assessment |
|---|---:|---|
| Standard structure and packaging | 8.0 | Correct standalone repository name, root module, license, README, examples, catalogs, and release tag. A conventional `main.tf` is absent, and examples use relative sources contrary to HashiCorp's reusable-example guidance. |
| Provider and Terraform versioning | 8.5 | `versions.tf` correctly declares minimum-only Terraform and provider constraints and the child module contains no provider blocks. CI tests only one recent Terraform/provider combination rather than the declared minimum and latest supported versions. |
| Public interface design | 7.0 | Inputs are strongly typed and grouped into provider-neutral and AWS-specific objects. The large `aws` object, repeated workload schemas, deprecated compatibility input, and exposed-but-rejected `private_cloud` mode increase cognitive load. |
| Validation and guardrails | 8.5 | The module validates bootstrap values, workload sizing, CIDRs, IP allocation, AMI selection, instance offerings, egress profiles, and EIP quotas before apply. Some guarantees still rely on aggregate `terraform_data` validation rather than focused resource preconditions or postconditions. |
| State stability and upgrades | 8.5 | Stable node keys, retained `moved`-block policy, replacement documentation, import examples, and deliberate bootstrap drift handling are unusually strong. Upgrade paths are documented but not exercised automatically against prior release state. |
| Security and least privilege | 7.0 | IMDSv2, encrypted EBS, optional KMS, S3 public-access blocks, standalone security-group rules, egress profiles, secret scanning, and scoped IAM options are present. Default allow-all egress and `s3:*`, secrets in user data/state, and mutable workflow action tags remain material risks. |
| Testing depth | 8.5 | Thirty native mock-provider tests cover every workload, network modes, AZ placement, NAT, Spot, image channels, NIC precedence, IP validation, S3 modes, per-node overrides, security, and hardening. There are no live AWS apply/destroy or upgrade-state tests. |
| CI and automation | 8.0 | CI runs formatting, generated-doc checks, TFLint, validation, a required-contract coverage gate, native tests, all examples, Trivy configuration scanning, and secret scanning. It lacks a version matrix, action SHA pinning, dependency automation, test reports, and a live integration lane. |
| Documentation and examples | 8.0 | README, generated input/output tables, upgrade guide, release guide, changelog, security policy, and three examples are clear. Advanced node groups, private subnet/NAT, Spot, GPU, storage, and upgrade workflows lack copyable examples or an architecture diagram. |
| Governance and release engineering | 6.5 | Semantic tags, changelog, contribution guidance, private vulnerability reporting, and automated GitHub releases exist. `main` has no branch protection, Dependabot security updates are disabled, release creation is not gated on the full validation workflow, and actions are not pinned immutably. |

## Top 10 Enhancements

### 1. Add live AWS integration tests

Create a dedicated low-cost AWS test account and a scheduled or manually approved workflow that applies and destroys the single-node smoke example. Verify EC2, ENI/private-IP assignment, EIP association, cloud-init rendering, security rules, IAM profiles, and teardown. HashiCorp explicitly distinguishes native tests from validation and warns that apply tests need isolated accounts and cleanup monitoring.

**Impact:** Highest. This catches provider and AWS API behavior that mocked plans cannot detect.

### 2. Build a minimum/latest compatibility matrix

Test the declared minimum Terraform version and the current supported version, plus the minimum and current AWS provider major/minor combinations. Keep reusable-module constraints as minimum-only, but prove those minimums continuously. Either raise a minimum immediately when it is no longer tested or supported, or keep a CI lane for it.

**Impact:** Very high. The published compatibility contract becomes evidence-backed instead of aspirational.

### 3. Expand contract tests across the behavior matrix

Implemented on 2026-10-27 with 30 plan-only native tests and a required-run coverage gate. Remaining follow-up: emit JUnit XML in CI for durable reporting.

**Impact:** Very high. Most module complexity lives in normalization and conditional planning, so this provides broad coverage without AWS cost.

### 4. Add automated upgrade and state-migration tests

Create fixtures that start from each supported released version, initialize representative state, upgrade to the candidate version, and assert that plans contain only documented changes. Exercise retained `moved` blocks, stable `for_each` keys, inline-to-standalone security-rule migration, node-group renames, and import blocks.

**Impact:** Very high. Avoiding unintended instance replacement is more important here than adding new features.

### 5. Separate the orchestration facade from composable implementation modules

Keep the current root interface as a backward-compatible, opinionated facade, but progressively move cohesive internals into flat modules such as `modules/network`, `modules/node`, and `modules/storage-access`. Use retained `moved` blocks for state continuity and expose submodules only when they are useful independently. Avoid a deeply nested module tree.

**Impact:** High. It reduces the maintenance burden of approximately 2,000 lines of interconnected root-module logic while preserving the consumer API.

### 6. Harden GitHub governance and the software supply chain

Protect `main`, require the Terraform workflow before merge, require reviews, enable Dependabot security/version updates, and pin every GitHub Action to a verified full commit SHA. Add CODEOWNERS for module and release-sensitive files. GitHub identifies full-SHA action pinning as the immutable option.

**Impact:** High. The repository provisions privileged cloud infrastructure and should not rely on movable action tags or unreviewed direct pushes.

### 7. Gate releases on validation and provenance

Make the release workflow call or depend on the full test workflow, verify that the tag is valid SemVer and points to an approved `main` commit, require a matching changelog entry, and generate an artifact attestation or signed provenance record. Keep existing releases immutable.

**Impact:** High. It prevents an incorrectly tagged or untested commit from becoming the distribution artifact.

### 8. Make examples consumer-realistic

Change copyable examples to use the immutable external Git source, as HashiCorp recommends, and move local-source validation fixtures under `tests/fixtures` or generate them during CI. Add focused examples for advanced node groups, private workers with NAT, Spot labs, GPU/AI Services, existing S3/KMS, and an upgrade/import scenario.

**Impact:** Medium-high. Examples are the practical API for most module consumers and should behave after being copied out of the repository.

### 9. Design a bootstrap mode that avoids secrets in Terraform state

Investigate appliance-compatible retrieval of registration codes and passwords from Secrets Manager or SSM at first boot, with an instance role scoped to one secret and an explicit rotation/version trigger. Terraform ephemeral values only solve this when the terminal resource exposes a write-only argument; EC2 user data currently remains persisted by the provider and AWS. Retain the current mode until the Zoom Node bootstrap path can consume a reference securely.

**Impact:** Medium-high. It addresses the module's clearest residual data-security limitation without pretending that `sensitive = true` removes values from state.

### 10. Introduce secure presets and clearer architecture documentation

Add an opt-in secure preset that selects workload-specific egress, granular S3 actions, versioning, lifecycle controls, and customer-managed KMS inputs while preserving current defaults until a major release. Add a resource-flow diagram showing network, ENI/EIP, security-group, IAM, log, and storage relationships, plus a decision table for standard workloads versus advanced node groups.

**Impact:** Medium. It lowers adoption effort for production deployments and makes security choices visible without surprising existing users.

## Recommended Sequence

1. CI matrix, expanded mock tests, and live smoke test.
2. Branch protection, dependency automation, action pinning, and release gating.
3. Upgrade-state tests before any structural refactor.
4. Composable internal modules with retained state moves.
5. Consumer examples, architecture documentation, and secure presets.
6. Appliance-compatible secret bootstrap research and implementation.

## Notable Strengths to Preserve

- Stable, human-readable `for_each` node identities.
- Minimum-only version constraints in the reusable module.
- Caller-owned provider configuration.
- Generated README input/output documentation.
- Catalog-driven image, instance, and workload defaults.
- Explicit upgrade, import, and replacement documentation.
- Standalone security-group rule resources.
- Sensitive output marking and prominent state warnings.
- Cross-platform example provider lock checksums.
- Local and CI parity through `scripts/check-repository.sh`.
