# GovTech ap-southeast-1 Explicit Zoom Nodes

This deployment root creates three Kubernetes control-plane nodes and five worker nodes in an existing VPC, subnet, security group, and IAM instance profile.

The configuration was copied without Terraform state. Do not manage the existing environment from this path until its authoritative state has been migrated to a configured remote backend; see [`../README.md`](../README.md).

It consumes the immutable standalone module release `v0.4.1` through exact `explicit_nodes`. Declarative moves preserve all eight EC2 instances, ENIs, and CloudWatch log groups while the existing security group and `ZoomNodeS3Access` IAM instance profile remain externally owned.

Network interface names are loaded by exact EC2 instance type from the shared `zoom-node-aws` instance catalog. The current `t3.xlarge` nodes use `ens5`; `m7i.2xlarge` uses `enp39s0`.

## Resources

| Hostname | Instance type | Network interface | Private IP | Source/destination check |
| --- | --- | --- | --- | --- |
| `sg01master1-ap-southeast-1a` | `t3.xlarge` | `ens5` | `10.0.101.251` | disabled |
| `sg01master2-ap-southeast-1a` | `t3.xlarge` | `ens5` | `10.0.101.252` | disabled |
| `sg01master3-ap-southeast-1a` | `t3.xlarge` | `ens5` | `10.0.101.253` | disabled |
| `sg01worker1-ap-southeast-1a` | `m7i.2xlarge` | `enp39s0` | `10.0.101.241` | enabled |
| `sg01worker2-ap-southeast-1a` | `m7i.2xlarge` | `enp39s0` | `10.0.101.242` | enabled |
| `sg01worker3-ap-southeast-1a` | `m7i.2xlarge` | `enp39s0` | `10.0.101.243` | enabled |
| `sg01worker4-ap-southeast-1a` | `m7i.2xlarge` | `enp39s0` | `10.0.101.244` | enabled |
| `sg01worker5-ap-southeast-1a` | `m7i.2xlarge` | `enp39s0` | `10.0.101.245` | enabled |

Control-plane ENIs disable source/destination checking so kube-vip can advertise its virtual IP. The ENI resources own this setting; the duplicate value observed through the EC2 instance resource is ignored.

Secondary ENI addresses assigned outside Terraform are preserved by lifecycle rules. The captured pre-migration state and AWS baseline contained only the configured primary addresses; no kube-vip secondary address was present during this migration.

## Update Behavior

Terraform ignores EC2 user-data changes after an instance has been created. Updating `registration_code` or `node_password` therefore supplies bootstrap values only to newly created or explicitly replaced instances; it does not reboot or rerun cloud-init on existing nodes.

The AWS provider also ignores the organization-managed `AttachedInstance`, `Owner`, `appliance`, and `team` tag keys so a plan does not remove values applied outside this deployment.

## Apply

Create an ignored local variables file and replace both bootstrap placeholders before planning:

```bash
cd deployments/govtech-ap-southeast-1-explicit-nodes

cp terraform.tfvars.example local.auto.tfvars
# Edit local.auto.tfvars with a fresh registration code and node password.

set -a
source ../../.env
set +a

terraform init -upgrade
terraform plan -out=.migration/govtech-v040.tfplan
# Optional: use when current EC2 capacity is a concern.
../../scripts/check-ec2-capacity.sh --terraform-plan .migration/govtech-v040.tfplan
terraform show -json .migration/govtech-v040.tfplan > .migration/govtech-v040-plan.json
# Review the JSON plan and apply only when EC2/ENI replacement and deletion counts are zero.
terraform apply .migration/govtech-v040.tfplan
```

The preflight is optional and does not affect Terraform planning or migration. Use it for Spot, GPU-backed, unusually large, multi-node, or single-AZ requests. It requires Capacity Manager and AWS Unified Operations; see [Optional capacity preflight](../../docs/prerequisites.md#optional-capacity-preflight).

## Destroy

```bash
cd deployments/govtech-ap-southeast-1-explicit-nodes

set -a
source ../../.env
set +a

terraform destroy
```

`local.auto.tfvars` is ignored by Git and loaded automatically. If it is unavailable during destroy, recreate it from the example; dummy bootstrap values are sufficient as long as they pass variable validation.

The source deployment used local Terraform state, which was not copied here. That state contains rendered cloud-init, including the registration code and node password. Migrate it securely to an encrypted, access-controlled remote backend before using this root to update or destroy the existing instances.
