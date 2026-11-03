# Tokyo AI Services Explicit Zoom Nodes

This deployment root creates two GPU-backed Zoom AI Services nodes in the existing Tokyo VPC.

The configuration was copied without Terraform state. Do not manage the existing environment from this path until its authoritative state has been migrated to a configured remote backend; see [`../README.md`](../README.md).

It consumes the immutable standalone module release `v0.4.1` through exact `explicit_nodes`. Declarative moves preserve the existing EC2 instances, ENIs, and CloudWatch log groups at their module addresses while the deployment-owned security group remains at its original root address.

## Resources

| Hostname | Instance type | Network interface | Private IP | Root volume | Elastic IPs |
| --- | --- | --- | --- | --- | --- |
| `jp01worker1-ap-northeast-1a` | `g6.12xlarge` | `enp39s0` | `10.2.101.241` | 500 GB gp3 | none |
| `jp01worker2-ap-northeast-1a` | `g6.2xlarge` | `enp39s0` | `10.2.101.242` | 500 GB gp3 | none |

Both nodes use AMI `ami-0f31cf9510e341030`, subnet `subnet-0f6e34349960f80b0` in `ap-northeast-1a`, and one shared security group created by this root.

## Update Behavior

Terraform ignores EC2 user-data changes after an instance has been created. Updating `registration_code` or `node_password` therefore supplies bootstrap values only to newly created or explicitly replaced instances; it does not reboot or rerun cloud-init on the existing node.

Review a saved migration plan before applying. Both nodes must show state moves into `module.zoom_node.module.node` with no replacement or deletion. Stop if either EC2 instance or ENI has a `delete`, `create_then_delete`, or `delete_then_create` action.

The AWS provider also ignores the organization-managed `AttachedInstance`, `Owner`, `appliance`, and `team` tag keys so a plan does not remove values applied outside this deployment.

## Security Group Rules

| Direction | Protocol | Port | Source/Destination | Purpose |
| --- | --- | ---: | --- | --- |
| Ingress | TCP | 8443 | `10.0.0.0/8` | Remote management |
| Ingress | All | All | `10.0.0.0/8` | Kubernetes and internal node communications |
| Egress | All | All | `0.0.0.0/0` | Outbound access |

## Apply

Create an ignored local variables file and replace both bootstrap placeholders before planning. Use a fresh registration code when adding or replacing a node:

```bash
cd deployments/tokyo-ai-services-explicit-node

cp terraform.tfvars.example local.auto.tfvars
# Edit local.auto.tfvars with a fresh registration code and node password.

set -a
source ../../.env
set +a

terraform init -upgrade
terraform plan -out=.migration/tokyo-v040.tfplan
# Optional: recommended for constrained GPU capacity.
../../scripts/check-ec2-capacity.sh --terraform-plan .migration/tokyo-v040.tfplan
terraform show -json .migration/tokyo-v040.tfplan > .migration/tokyo-v040-plan.json
# Review the JSON plan and apply only when EC2/ENI replacement and deletion counts are zero.
terraform apply .migration/tokyo-v040.tfplan
```

The preflight is optional and does not affect Terraform planning or migration. It is recommended here because GPU instance capacity can be constrained by Region and Availability Zone. It requires Capacity Manager and AWS Unified Operations; see [Optional capacity preflight](../../docs/prerequisites.md#optional-capacity-preflight).

## Destroy

```bash
cd deployments/tokyo-ai-services-explicit-node

set -a
source ../../.env
set +a

terraform destroy
```

`local.auto.tfvars` is ignored by Git and loaded automatically. If it is unavailable during destroy, recreate it from the example; dummy bootstrap values are sufficient as long as they pass variable validation.

The source deployment used local Terraform state, which was not copied here. That state contains rendered cloud-init, including the registration code and node password. Migrate it securely to an encrypted, access-controlled remote backend before using this root to update or destroy the existing nodes.
