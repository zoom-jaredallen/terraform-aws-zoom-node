# Prerequisites

## Tooling

| Tool | Requirement | Purpose |
|---|---|---|
| Terraform | `>= 1.7.0` | Module execution and native tests |
| AWS provider | `>= 6.0` | AWS resources and data sources |
| Random provider | `>= 3.6` | Optional compliant password generation |
| AWS CLI | Current v2 | Authentication and operator workflows |
| AWS CLI for capacity preflight | `>= 2.39.1` | EC2 Capacity Manager supportability query |
| `jq` | Current stable release | Saved-plan capacity extraction |

Maintainers also need `terraform-docs`, TFLint, and Trivy to run `./scripts/check-repository.sh`.

## AWS account and identity

The deployment identity must be able to read account, Region, Availability Zone, instance-offering, AMI, VPC, subnet, Elastic IP, and Service Quotas information. Its create/update/delete permissions must cover the resources selected by the configuration:

| Service | Required when |
|---|---|
| EC2 and VPC | Always; instances, ENIs, EBS, security groups, EIPs, and optionally VPC networking/NAT |
| IAM | Module-managed S3 access profiles are selected |
| S3 | A Hybrid Recording or generic access bucket is created or managed |
| KMS | Customer-managed keys protect EBS, CloudWatch Logs, or S3 objects |
| CloudWatch Logs | Node log groups are managed |
| Service Quotas | Plan-time Elastic IP quota validation runs |

Use a deployment role scoped to the chosen features. Validate the final policy in the customer account with IAM Access Analyzer and CloudTrail rather than granting permanent administrator access.

## Zoom Node images

Zoom Node AMIs are private and regional. Obtain a production AMI and, only when required, an SSH-enabled development AMI. The image must be visible to the target account, in the target Region, in the `available` state, and use the `x86_64` architecture.

Shared encrypted AMIs also require access to their backing KMS key. Copying an AMI to another account or Region creates a new AMI ID. See [AMI management](ami-management.md).

## Bootstrap inputs

- A fresh Zoom Node registration code containing exactly 16 alphanumeric characters.
- Either a caller-supplied password meeting the module policy or `generate_node_password = true`.
- A DNS domain used to generate node FQDNs.
- Correct network-interface mappings for every overridden instance type.

Registration codes expire quickly. Existing nodes retain their initial bootstrap because instance user-data drift is ignored, but every new or replaced node requires a valid code at first boot.

## Network and quota readiness

- Select one or two Availability Zones that offer every chosen instance type.
- Ensure each subnet has space for all primary and secondary private IPs.
- Ensure public deployments have enough regional Elastic IP quota.
- Ensure On-Demand or Spot vCPU quotas cover the selected instance families.
- Request GPU quotas and verify point-in-time capacity before deploying AI Services.
- Provide outbound routing for nodes that must reach Zoom Cloud, S3, package endpoints, or other services.
- For existing networks, supply route tables, internet/NAT egress, DNS, and network ACLs outside the module.

The module validates exact-AZ offerings and the regional Elastic IP quota during planning. It does not validate On-Demand, Spot, or GPU vCPU quotas. These checks do not reserve AWS capacity.

## State backend

For shared or long-lived deployments, configure a caller-owned remote backend with encryption, access control, locking, versioning, and recovery procedures. The module does not create or configure its own backend. State and saved plans contain rendered cloud-init values.
