# Deployment Migration and Legacy Deprecation Design

## Goal

Migrate the four existing Zoom Node deployment roots to the standalone `terraform-aws-zoom-node` facade without unplanned EC2, ENI, EIP, VPC, subnet, or storage replacement, then deprecate redundant compatibility inputs and remove them only in the next major release.

## Repositories

- Module: `/Users/jaredallen/Documents/projects/terraform-aws-zoom-node`
- Deployment roots: `/Users/jaredallen/Documents/projects/zoom-node-cloudformation/terraform/deployments`

## Safety Contract

- Every deployment migration starts from a state backup and an immutable module release.
- An empty or unexpected state is a stop condition. It must never be interpreted as approval to recreate infrastructure.
- The first migration plan for a live deployment may contain state moves and explicitly accepted in-place tag/rule changes, but no EC2, ENI, EIP, VPC, subnet, route, or bucket replacement.
- Existing hostnames, private IPs, EIPs, instance IDs, ENI IDs, source/destination-check values, instance profiles, security groups, AMIs, instance types, disks, and user-data lifecycle behavior remain unchanged unless a separate maintenance change is approved.
- Registration codes and passwords remain sensitive and must not be committed. Existing instances continue ignoring user-data changes.
- Deployment migrations are performed one at a time, with post-apply AWS identity checks before proceeding.
- The standalone module remains the only supported public module entry point. Private implementation modules are not called directly by deployments.

## Required Module Capability

The current `node_groups` interface cannot represent the exact hostname and private-IP inventory used by Tokyo, GovTech, and Sydney. Add a provider-neutral `explicit_nodes` map keyed by stable node identity. Each entry must support exact node name/FQDN, role, AMI/channel, instance type, root volume, private IP list, EIP count, subnet tier/index, purchase option, source/destination check, IMDS hop limit, and either a managed security/IAM profile or externally supplied security-group IDs and IAM instance-profile name.

```hcl
explicit_nodes = map(object({
  node_name                            = optional(string, null)
  fqdn                                 = optional(string, null)
  role                                 = string
  instance_type                        = string
  image_channel                        = optional(string, null)
  image_id                             = optional(string, null)
  root_volume_gb                       = number
  private_ips                          = list(string)
  elastic_ips_per_node                 = optional(number, 0)
  subnet_tier                          = string
  subnet_index                         = optional(number, null)
  purchase_option                      = optional(string, null)
  source_dest_check                    = optional(bool, true)
  metadata_http_put_response_hop_limit = optional(number, null)
  security_profile                     = optional(string, null)
  security_group_ids                   = optional(list(string), [])
  iam_profile_key                      = optional(string, null)
  iam_instance_profile_name            = optional(string, null)
}))
```

When `node_name` is null, use the map key. When `fqdn` is null, append the root `domain_name`; migrations that must preserve a non-FQDN appliance hostname set `fqdn` explicitly to the existing value. Exactly one security ownership mode is allowed: a managed `security_profile` or non-empty external `security_group_ids`. IAM may be managed through `iam_profile_key`, external through `iam_instance_profile_name`, or absent when both are null.

Externally supplied security groups and instance profiles remain owned outside the module. The module must not create substitute resources for those nodes. Managed workload and node-group behavior remains unchanged.

## Deployment Strategy

### us-west-2-labcluster

Already consumes the legacy local module path. Switch only to an immutable standalone-module tag. The module's retained state moves handle the internal `network`, `node`, and `storage-access` extraction. Its currently visible local state is empty, so execution must first determine whether the environment is destroyed, the wrong working directory is being inspected, or authoritative state exists elsewhere.

### Tokyo AI Services

Adopt `explicit_nodes` in `network_mode = "use_existing"`. Preserve both exact hostnames, private IPs, AMIs, GPU instance types, 500 GB disks, and zero EIPs. Keep the existing deployment-managed security group initially and pass its ID into both explicit nodes. Move EC2, ENI, and log-group state into `module.zoom_node.module.node`; retain the security group at its current deployment address.

### GovTech

Adopt `explicit_nodes` in `network_mode = "use_existing"`. Preserve all eight exact hostnames and private IPs. Continue using externally managed security group `sg-0d9070fbb749a5ff4` and instance profile `ZoomNodeS3Access`. Move EC2, ENI, and log-group state into `module.zoom_node.module.node`.

### Sydney Public Four Node

Adopt `explicit_nodes` with module-managed new VPC networking and four exact node identities. Retain the current deployment-managed security group during the first migration. If authoritative state contains resources, move VPC, IGW, subnet, route table, association, EC2, ENI, EIP, EIP-association, and log-group state to module addresses. Its currently visible local state is empty, so do not apply a creation plan unless a fresh deployment is explicitly intended.

## Deprecation Candidates

| Legacy input | Replacement | Removal target |
|---|---|---|
| `enable_least_privilege_egress` | `aws.security_group_egress_profiles` | `v1.0.0` |
| `aws.subnet_cidrs` | `aws.public_subnet_cidrs` | `v1.0.0` |
| `aws.network_interface_names_by_instance_family` | catalog or `aws.network_interface_names_by_instance_type` | `v1.0.0` |
| `aws.enable_public_ipv4_on_boot` | none; Zoom Nodes use explicit ENIs/EIPs | `v1.0.0` |
| Dedicated `hybrid_recording_s3_*` inputs | `aws.s3_bucket_access` targeting `HybridRecording` | `v1.0.0` |
| `hybrid_recording_s3_bucket_name` output | `s3_bucket_names["hybrid_recording"]` | `v1.0.0` |

The next minor release documents replacements and emits non-blocking Terraform `check` warnings when deprecated inputs are used. It must reject conflicting legacy and replacement configuration. Removal occurs only after every maintained deployment and example uses the replacements and at least one released minor version has carried the warnings.

The warning addresses are stable test contracts:

- `check.deprecated_enable_least_privilege_egress`
- `check.deprecated_subnet_cidrs`
- `check.deprecated_instance_family_nic_map`
- `check.deprecated_public_ipv4_on_boot`
- `check.deprecated_hybrid_recording_s3_inputs`

## Out of Scope

- Removing `node_groups`, image catalogs, exact AMI overrides, or exact NIC overrides.
- Replacing existing instances merely to normalize tags, IAM, security groups, or cloud-init.
- Publishing to the Terraform Registry.
- Migrating state to a new backend as part of module adoption.

