# EU West 3 Paris Lab Cluster

This root defines an independent eight-node Zoom Node lab in `eu-west-3`. It creates one Meetings Hybrid node, one Kubernetes master, five private Kubernetes workers, one public On-Demand `g6.12xlarge` AI Services node, a new VPC, one NAT Gateway, and the encrypted `zoomnode-paris-labcluster-s3` bucket.

All nodes use `eu-west-3b`. The AI Services node uses the public `10.30.0.0/24` subnet so its Elastic IP is reachable for management. The deployment uses VPC `10.30.0.0/16`, which does not overlap the US West lab's `10.20.0.0/16` network.

The root is pinned to immutable module release `v0.4.1`. Production and development AMIs resolve from [`../aws-ami-catalog.json`](../aws-ami-catalog.json); optional `prod_ami_id` and `dev_ami_id` variables can override the catalog during image testing. The Kubernetes master uses the development image, while all other groups use production.

## Prerequisites

The topology requires eight new Elastic IPs: five for Meetings Hybrid, one for the Kubernetes master, one for AI Services, and one for the NAT Gateway. With one pre-existing address in `eu-west-3`, the account requires a quota of at least nine. Request ten for operational headroom before expecting a successful plan:

```bash
aws service-quotas request-service-quota-increase \
  --region eu-west-3 \
  --service-code ec2 \
  --quota-code L-0263D0A3 \
  --desired-value 10
```

At design time, the account had sufficient Standard and G/VT On-Demand vCPU quotas, all four selected instance types were offered in `eu-west-3b`, and `zoomnode-paris-labcluster-s3` was globally available. Recheck these point-in-time prerequisites before applying.

## Safety

This directory intentionally contains no Terraform state, backend configuration, registration code, node password, saved plan, or Terraform working directory in source control. It is a new deployment, not a migration of the US West state. Do not apply it without a fresh Zoom registration code and explicit deployment approval.

The module generates the node password. Terraform state and saved plans contain rendered bootstrap credentials, so configure an encrypted, access-controlled remote backend before a long-lived or production deployment.

## Plan

```bash
cd deployments/eu-west-3-paris-labcluster
cp terraform.tfvars.example local.auto.tfvars
# Replace the registration_code placeholder with a fresh code.
terraform init -upgrade
terraform plan -out=tfplan
# Optional for the GPU-backed fixed-AZ request.
../../scripts/check-ec2-capacity.sh --terraform-plan tfplan --capacity-manager-region us-west-2 --minimum-score medium
```

The committed placeholder is intentionally invalid so an accidental plan or apply fails closed. Automated plan-only validation may explicitly pass `-var='registration_code=AAAAAAAAAAAAAAAA'`; never apply a plan created with that dummy value.

The Capacity Manager check is optional and advisory. It does not reserve capacity or guarantee a later launch. At design time, both `eu-west-3b` and `eu-west-3c` scored high for one On-Demand `g6.12xlarge` instance.

## Topology

| Group | Count | Instance type | Root disk | Private IPs per node | EIPs per node | Subnet |
|---|---:|---|---:|---:|---:|---|
| Meetings Hybrid | 1 | `c8i-flex.2xlarge` | 200 GB | 5 | 5 | public |
| Kubernetes master | 1 | `c7i-flex.xlarge` | 500 GB | 1 | 1 | public |
| Kubernetes workers | 5 | `c8i.4xlarge` | 200 GB | 1 | 0 | private |
| AI Services | 1 | `g6.12xlarge` | 500 GB | 1 | 1 | public |

All groups use On-Demand purchasing. Workers have no direct public ingress and use the NAT Gateway for outbound traffic. AI Services allows management TCP and UDP from the configured management CIDRs through its Elastic IP. The single Availability Zone, NAT Gateway, and Kubernetes master are intentional lab simplifications and single points of failure.
