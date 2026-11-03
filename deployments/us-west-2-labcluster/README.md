# US West 2 Lab Cluster

This configuration defines, but does not automatically apply, an eight-node Zoom Node lab in `us-west-2`. It creates one Meetings Hybrid node, one Kubernetes master, five private Kubernetes workers, one private On-Demand AI Services node, a new VPC, one NAT Gateway, and the encrypted `zoomnode-labcluster-s3` bucket. Existing nodes use `us-west-2a`; the AI Services group uses a dedicated `10.20.2.0/24` private subnet in `us-west-2b`. Confirm current `g6.12xlarge` capacity before applying because GPU capacity is constrained by Availability Zone.

This copied root intentionally contains no Terraform state; see [`../README.md`](../README.md). Its source deployment was already classified as destroyed, so a future apply is a new environment creation rather than an existing-state migration.

The deployment is pinned to the immutable standalone module release `v0.4.1`. The source deployment's authoritative state was empty and no matching EC2 instances remained in AWS, so this root is classified as destroyed. Do not apply it unless recreating the lab is explicitly intended.

Zoom Node AMIs are customer-owned inputs in `v0.4.1`. This root resolves the production and development channels from [`../aws-ami-catalog.json`](../aws-ami-catalog.json) for `aws_region`. Optional `prod_ami_id` and `dev_ami_id` variables override the catalog for this deployment. The Kubernetes master selects the development channel; the Meetings Hybrid, Kubernetes worker, and AI Services groups select production.

## Before Planning

The topology needs 92 Standard On-Demand vCPUs, 48 On-Demand G/VT vCPUs, and seven Elastic IPs: six attached to nodes and one for the NAT Gateway. Check the account's actual quotas before planning:

```bash
aws service-quotas get-service-quota --region us-west-2 --service-code ec2 --quota-code L-1216C47A
aws service-quotas get-service-quota --region us-west-2 --service-code ec2 --quota-code L-DB2E81BA
aws service-quotas get-service-quota --region us-west-2 --service-code ec2 --quota-code L-0263D0A3
aws ec2 describe-addresses --region us-west-2
```

Request quota increases in Service Quotas if the available values are below the required totals. A sufficient quota does not guarantee physical capacity for the selected instance types.

S3 bucket names are globally unique. If `zoomnode-labcluster-s3` belongs to another account, choose another name before apply. To adopt a bucket already owned by this account, change its mode to `use_existing`.

## Plan

Create the ignored local variables file from the committed example, then replace its placeholder with a fresh registration code:

```bash
cd deployments/us-west-2-labcluster
cp terraform.tfvars.example local.auto.tfvars
# Edit local.auto.tfvars and replace the registration_code placeholder.
terraform init -upgrade
terraform plan -out=tfplan
# Optional: recommended here because this deployment uses a large GPU instance in a fixed AZ.
../../scripts/check-ec2-capacity.sh --terraform-plan tfplan --minimum-score medium
# Review the plan, then apply the exact saved plan when its score and changes are acceptable.
terraform apply tfplan
```

The preflight is optional and Terraform can plan or apply without it. It is recommended for this lab because the deployment includes a GPU-backed AI Services node in a fixed Availability Zone. It requires Capacity Manager and AWS Unified Operations; see [Optional capacity preflight](../../docs/prerequisites.md#optional-capacity-preflight). A score is advisory and does not reserve or guarantee capacity.

For a future recreation, save the plan and confirm that all proposed creates are intentional. An empty state is not a migration source and must never be used to infer that existing infrastructure can be adopted automatically.

`local.auto.tfvars` is loaded automatically and ignored by Git. Do not put AWS credentials in this file; authenticate with AWS SSO, an AWS profile, or environment variables. The AWS region defaults to `us-west-2`, and the example keeps that choice explicit for local customization.

The node password is intentionally absent from the variables file because the module uses `generate_node_password = true`. As an alternative to a local file, supply only the registration code with `TF_VAR_registration_code`.

The local file can also override the single Availability Zone, management CIDRs, globally unique S3 bucket name, and instance type for each node group. Node counts, disks, subnet layout, private-IP allocation, EIP counts, image channels, IAM profiles, and security profiles remain in `main.tf` so topology changes stay reviewable.

The module generates the Zoom Node password. After an apply, retrieve it with:

```bash
terraform output -raw generated_node_password
```

Terraform state and saved plan files are credential-bearing because rendered EC2 user data contains both the registration code and generated password. Use an encrypted, access-controlled remote backend before production use, and do not commit local state or plan files.

Bootstrap user data is immutable after an instance is created. Updating `registration_code` supplies the new value to newly added or explicitly replaced nodes without changing, rebooting, or rerunning cloud-init on existing nodes.

## Lab Risks

All node groups use On-Demand capacity. The `g6.12xlarge` AI Services node provides four NVIDIA L4 GPUs, but launch capacity may not be available in every `us-west-2` Availability Zone.

The single NAT Gateway and single Kubernetes master are intentional lab cost choices and single points of failure. Workers and AI Services nodes have no EIPs and no direct public ingress; outbound traffic uses the NAT Gateway, while application ingress is expected to route through the master. The AI Services subnet in `us-west-2b` uses the NAT Gateway in `us-west-2a`, which introduces cross-AZ data-processing charges. Terraform does not configure Kubernetes, kube-vip, IP forwarding, or application routing inside the appliances.
