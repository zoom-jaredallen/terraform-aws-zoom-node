# Terraform Upgrade Guide

## Semantic versioning

Published Zoom Node Terraform module releases follow Semantic versioning. Pin production consumers to an immutable tag. Patch releases contain compatible fixes, minor releases add backward-compatible capabilities, and major releases may require configuration or state migration.

The following are compatibility guarantees within a major release:

- Existing input names, defaults, output names, and documented resource addresses remain compatible.
- Stable node keys, such as `meetings_hybrid-01`, remain the identity of stateful per-node resources.
- Once added, moved blocks are retained for the lifetime of the major release. Removing a moved block is treated as a breaking change.
- New security, encryption, retention, and lifecycle controls remain opt-in unless a security issue requires a documented breaking change.

Always read `CHANGELOG.md`, back up remote state, run `terraform init -upgrade`, and review a saved plan before applying a module upgrade.

## Standalone security-group rules

The module now manages rules with standalone security-group rules instead of inline blocks on `aws_security_group.zoom_node`. The security groups retain their existing state addresses and EC2 attachments.

Terraform cannot move an inline nested block into a standalone resource address. On the first apply after upgrading, Terraform therefore removes the inline rules and creates equivalent standalone rules. This can cause a brief traffic interruption while AWS reconciles the rules. Schedule the first apply in a maintenance window, verify that only rule resources change, and avoid combining this migration with unrelated node changes.

After the migration, each rule has a stable key derived from its security profile, protocol, port range, and CIDR. Description-only changes do not change rule identity.

## Replacement triggers

Review every plan for the `-/+` replacement marker. Common changes have these expected effects:

| Change | Expected behavior |
|---|---|
| AMI ID or image channel | Replaces the EC2 instance. A fresh Zoom registration code is required. |
| Primary subnet or ENI topology | Replaces the ENI and can replace the instance. |
| Node key rename, node-count reduction, or group removal | Destroys resources under the old stable key. Use a moved block for intentional renames. |
| Root-volume KMS key | Can replace the instance/root volume. Treat as a maintenance event. |
| Root-volume size increase | Normally modifies the volume in place; shrinking is unsupported. |
| Instance type | Normally stops and starts the instance, but confirm the provider plan and NIC mapping. |
| Security-group rules or egress profile | Updates rules without replacing EC2 instances. |
| CloudWatch log retention or KMS key | Updates or replaces the log group only, according to the provider plan. |
| S3 versioning or lifecycle policy | Updates bucket controls without replacing nodes. |
| Registration code, password, or rendered user data | Existing instance bootstrap data is intentionally ignored after creation. |
| Source/destination check | Updates the primary ENI in place; disable it only for nodes that require routing behavior such as kube-vip. |

## State moves

### Flat implementation-module migration

The root module now delegates AWS resource ownership to private `network`, `node`, and `storage-access` modules. The public variables, outputs, stable node keys, and generated-password state address are unchanged. Retained `moved` blocks migrate existing state from root resource addresses to the child modules during the first plan after upgrade.

Expect the plan to show messages such as `aws_instance.zoom_node["meetings_hybrid-01"] has moved to module.node.aws_instance.zoom_node["meetings_hybrid-01"]`. A pure internal migration must not show destruction or replacement for those resources. Back up state and stop if the plan proposes `-/+` changes that are not explained by other configuration changes.

When a configuration rename changes a Terraform address but not the real infrastructure, add a declarative `moved` block to the calling root or module instead of using destructive recreation. Commit the block with the change and retain it for downstream consumers that may skip intermediate releases.

```hcl
moved {
  from = module.zoom_node.aws_instance.zoom_node["old-key"]
  to   = module.zoom_node.aws_instance.zoom_node["new-key"]
}
```

Do not use a moved block when the underlying node must be rebuilt, such as an AMI replacement requiring a fresh registration code.

## Import existing resources

Import existing resources only after configuring the module so its stable keys, VPC/subnet selection, names, and IP allocation match the deployed infrastructure. Back up state and use declarative import blocks so the operation can be reviewed.

```hcl
import {
  to = module.zoom_node.module.node.aws_instance.zoom_node["meetings_hybrid-01"]
  id = "i-0123456789abcdef0"
}

import {
  to = module.zoom_node.module.node.aws_network_interface.zoom_node["meetings_hybrid-01"]
  id = "eni-0123456789abcdef0"
}

import {
  to = module.zoom_node.module.node.aws_security_group.zoom_node["MeetingsHybrid"]
  id = "sg-0123456789abcdef0"
}
```

Standalone ingress and egress rules can be imported using their AWS security-group rule IDs (`sgr-...`) and the exact deterministic address shown by a speculative plan. Existing module-managed inline rules normally migrate during apply and do not need manual import.

Network resources import under `module.zoom_node.module.network`, and S3/IAM resources import under `module.zoom_node.module.storage_access`. Always use the address shown by the current module version rather than an address copied from an older release.

Run `terraform plan` after each import batch. Resolve every unexpected update or replacement before applying; import records state ownership but does not make the configuration match the remote object.

## Customer-managed KMS keys

KMS inputs reference keys owned outside this module. The caller must ensure each key policy permits the deployment principal, CloudWatch Logs service where applicable, and the instance role that accesses encrypted S3 objects. Removing or disabling a referenced key can make logs, volumes, or objects unreadable.

S3 lifecycle settings are managed only for buckets created by the module. Existing buckets remain under their existing owner's versioning, lifecycle, and encryption controls.
