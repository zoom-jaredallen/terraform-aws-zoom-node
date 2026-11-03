# Sydney Public Four-Node Zoom Node Deployment

This deployment root manages an existing public-facing Zoom Node environment in a dedicated VPC in `ap-southeast-2`. The previously orphaned AWS resources were adopted into local Terraform state through declarative imports and the root is pinned to immutable standalone module release `v0.4.1`.

The configuration was copied without Terraform state. Do not manage the existing environment from this path until its authoritative state has been migrated to a configured remote backend; see [`../README.md`](../README.md).

## Resources

| Field | Value |
| --- | --- |
| Region | `ap-southeast-2` |
| Availability Zone | `ap-southeast-2a` |
| VPC | created by this Terraform root, `10.20.0.0/16` |
| Public subnet | created by this Terraform root, `10.20.101.0/24` |
| Nodes | 4 x `t3.large` |
| AMI | `ami-06fa0d385e7d8a382` |
| Root volume | `500 GB` gp3 |
| Network | 1 ENI per node, 1 private IP per ENI, 1 Elastic public IP per node |
| Management sources | `38.99.100.7/32`, `180.150.42.155/32` |

## Nodes

| Hostname | Private IP |
| --- | --- |
| `syd01node1-ap-southeast-2a` | `10.20.101.10` |
| `syd01node2-ap-southeast-2a` | `10.20.101.20` |
| `syd01node3-ap-southeast-2a` | `10.20.101.30` |
| `syd01node4-ap-southeast-2a` | `10.20.101.40` |

## Security Group Rules

| Direction | Protocol | Port | Source/Destination | Purpose |
| --- | --- | ---: | --- | --- |
| Ingress | TCP | 8443 | `38.99.100.7/32`, `180.150.42.155/32` | Remote management |
| Egress | All | All | `0.0.0.0/0` | Outbound access |

## Plan

```bash
cd deployments/sydney-public-four-node-new-vpc

export TF_VAR_registration_code='<fresh 16-character Zoom registration code>'
export TF_VAR_node_password='<Zoom Node password>'

terraform init -upgrade
terraform plan
```

The post-import plan is clean. The four EC2 instances were returned to their pre-migration `stopped` state after adoption. A future plan must preserve the recorded VPC, subnet, route, security group, instance, ENI, EIP, and association IDs; stop if Terraform proposes replacement or deletion.

## Apply

```bash
terraform plan -out=.migration/sydney.tfplan
# Optional: use when current EC2 capacity is a concern.
../../scripts/check-ec2-capacity.sh --terraform-plan .migration/sydney.tfplan
terraform show -json .migration/sydney.tfplan > .migration/sydney-plan.json
terraform apply .migration/sydney.tfplan
```

The preflight is optional and does not affect Terraform planning or apply. Use it for Spot, GPU-backed, unusually large, multi-node, or single-AZ requests. It requires Capacity Manager and AWS Unified Operations; see [Optional capacity preflight](../../docs/prerequisites.md#optional-capacity-preflight).

## Destroy

```bash
export TF_VAR_registration_code=AAAAAAAAAAAAAAAA
export TF_VAR_node_password='ZoomNode1!'

terraform destroy
```

Dummy bootstrap values are sufficient for destroy as long as they pass variable validation.
