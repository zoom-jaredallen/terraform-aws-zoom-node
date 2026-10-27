# Flat Implementation Module Extraction

## Goal

Keep the published root module interface compatible while moving AWS resource ownership into three private, flat implementation modules:

- `modules/network`
- `modules/node`
- `modules/storage-access`

The root remains the facade. It owns the public variables and outputs, catalog loading, workload and node normalization, validation, generated password, cloud-init rendering, and cross-module orchestration.

## Compatibility Contract

- Do not rename or remove root inputs or outputs.
- Preserve normalized node keys, security profile keys, IAM profile keys, and S3 access keys.
- Preserve existing resource `count` and `for_each` keys inside the child modules.
- Add declarative `moved` blocks for every managed resource transferred from the root.
- Keep generated password state at its existing root address.
- Child modules are private implementation details and are not independently documented or versioned.

## Module Responsibilities

### Network

Own managed VPC, internet gateway, public and private subnets, route tables, NAT resources, associations, and existing-network data lookups. Return effective network IDs, CIDRs, DNS servers, and NAT details.

### Storage Access

Own S3 buckets and controls, IAM roles, instance profiles, and bucket-scoped policies. Receive normalized IAM and storage records from the facade and return instance-profile and bucket names.

### Node

Own workload security groups and rules, ENIs, CloudWatch log groups, EC2 instances, Elastic IPs, and EIP associations. Receive fully normalized node, network, security, cloud-init, and instance-profile data from the facade.

## Dependency Model

The root calls the modules once each without `count` or `for_each`, allowing whole-resource state moves. `module.node` depends on `module.network` and `module.storage_access`, preserving the prior ordering for routes, internet gateways, and instance profiles.

## Verification

- Static migration contract verifies all child modules and `moved` declarations.
- Native mocked tests continue to cover root behavior through child-module contract outputs.
- Formatting, validation, documentation, linting, and security checks remain green.

