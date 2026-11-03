# Terraform Registry Readiness

This checklist tracks the module against HashiCorp's public module conventions. GitHub releases are the current distribution mechanism; Registry publication remains intentionally deferred.

## Public Registry requirements

| Requirement | Status | Evidence or action |
|---|---|---|
| Public GitHub repository | Ready | Repository is publicly accessible |
| Repository name `terraform-<PROVIDER>-<NAME>` | Ready | `terraform-aws-zoom-node` |
| One-sentence GitHub description | Ready | “Deploy Zoom Node workloads on AWS with Terraform.” |
| Standard root module structure | Ready | Root `main.tf`, `variables.tf`, `outputs.tf`, `versions.tf`, README, examples, and tests |
| Semantic-version release tag | Ready | Immutable tags through `v0.4.1` |
| Root README | Ready | Narrative usage plus generated requirements, providers, resources, inputs, and outputs |
| License | Ready | Apache-2.0 |
| Examples | Partial | New VPC, existing VPC, smoke, and customer AMI catalog roots exist, but use local module sources for repository testing |

The Registry automatically derives module requirements, providers, resources, inputs, outputs, examples, and submodules from the repository. Keep API tables generated with `terraform-docs`; do not hand-maintain a competing reference.

## Publication checklist

Before enabling Registry publication:

1. Confirm the final GitHub organization and namespace ownership.
2. Confirm the official support owner and public support channel.
3. Run `./scripts/check-repository.sh` from a clean checkout.
4. Confirm every example resolves the intended immutable release.
5. Confirm no credentials, state, plans, `.env`, local variable files, or private AMI IDs are tracked.
6. Publish a GitHub release for the tag and verify release notes.
7. Sign in to the Terraform Registry with the owning GitHub identity and import the module.
8. Verify the rendered Registry documentation and example discovery.

Before publication, replace each example's local `source = "../.."` with the immutable release source consumers should copy. Until then, the local source deliberately keeps repository validation focused on the working tree.

## Partner-readiness work

HashiCorp's partner program has a higher operating bar than basic public publication. Before pursuing it, complete or formally assign:

- an official Zoom-owned repository and namespace;
- a documented support contact, escalation path, and maintenance commitment;
- protected branches and required CI checks;
- release provenance and artifact/signing policy;
- live AWS smoke-test policy for release candidates;
- response procedures for security disclosures and provider-breaking changes;
- an explicit compatibility matrix for Terraform and AWS provider versions.

## References

- [Publish modules to the Terraform Registry](https://developer.hashicorp.com/terraform/registry/modules/publish)
- [Standard module structure](https://developer.hashicorp.com/terraform/language/modules/develop/structure)
- [HashiCorp technology partner program](https://developer.hashicorp.com/terraform/docs/partnerships)
