# US East 1 Lab Cluster Runbook

This runbook describes how Terraform builds and operates the `use1lab` Zoom Node environment. Run commands from `deployments/us-east-1-labcluster`.

## 1. Authenticate and initialize

Export AWS credentials through an SSO profile or an ignored `.env` file, then confirm the account before making changes:

```bash
set -a
source ../../.env
set +a

aws sts get-caller-identity
terraform init
terraform validate
```

The expected account is `626657815993` and the region is `us-east-1`.
The provider also enforces this value through `allowed_account_ids`, so credentials for another account fail before Terraform reads AMIs, S3 settings, or other deployment resources.

## 2. Supply sensitive values

Create the ignored local variables file from the example:

```bash
cp terraform.tfvars.example local.auto.tfvars
```

Set a fresh Zoom Node registration code in `local.auto.tfvars`. Terraform generates the node password and stores both rendered values in sensitive Terraform state. Never commit `local.auto.tfvars`, state, or saved plans.

## 3. Create the network

The module uses `network_mode = "create_new"` and creates:

- VPC `10.40.0.0/16` with DNS support and hostnames enabled.
- Public subnet `10.40.0.0/24` in `us-east-1a`.
- Private CPU subnet `10.40.1.0/24` in `us-east-1a`.
- Private GPU subnet `10.40.2.0/24` in `us-east-1b`.
- Internet Gateway and public default route.
- NAT Gateway, NAT EIP, and private default route.
- Route-table associations for every managed subnet.

Private workers and AI Services use NAT egress. They do not receive individual EIPs.

Terraform waits 90 seconds after the network converges before creating nodes. Override `aws.network_stabilization_delay` only when another readiness mechanism exists.

## 4. Create ENIs and Elastic IPs

Each node receives one stable ENI and deterministic private addresses:

- Meetings Hybrid: `10.40.0.10` through `10.40.0.14`, with five EIPs.
- Kubernetes masters: `10.40.0.20`, `.30`, and `.40`, with one EIP each.
- Kubernetes workers: `10.40.1.60`, `.70`, `.80`, and `.90`, with no EIPs.
- AI Services: `10.40.2.110`, with no EIP.

The module associates EIPs with standalone ENIs before EC2 instances boot. This gives public nodes working internet access before cloud-init attempts Zoom registration.

## 5. Create security groups

`source_cidrs` defines reusable traffic sources:

```hcl
source_cidrs = {
  zoom_clients        = ["0.0.0.0/0"]
  remote_management_1 = var.management_cidrs
  internal_traffic    = ["10.40.0.0/16"]
}
```

Each node group selects a workload-specific `security_profile`. The module creates standalone ingress and egress rule resources. Management TCP/8443 is limited to `management_cidrs`; Kubernetes internal traffic uses the VPC CIDR. Default egress is unrestricted so registration and package downloads can reach Zoom and AWS services.

Review generated rules with:

```bash
terraform output security_group_ids
aws ec2 describe-security-group-rules \
  --region us-east-1 \
  --filters Name=group-id,Values=<security-group-id>
```

## 6. Create IAM roles, profiles, and S3 storage

The deployment creates the encrypted bucket named by `s3_bucket_name`. The `kubernetes` IAM profile receives bucket and object access because each Kubernetes node uses `iam_profile_key = "kubernetes"`.

Terraform creates:

- An EC2 trust role for each required IAM profile key.
- An instance profile attached to the selected EC2 nodes.
- A bucket-scoped IAM policy covering the bucket ARN and `bucket/*`.
- S3 public-access blocking and server-side encryption.

Inspect the generated names with:

```bash
terraform output iam_instance_profile_names
terraform output s3_bucket_names
```

## 7. Configure EC2 and IMDSv2

Every node requires IMDSv2 and sets the HTTP PUT response hop limit to `3`:

```hcl
metadata_http_put_response_hop_limit = 3
```

The masters set `source_dest_check = false` for kube-vip. Other nodes retain source/destination checking. Root volumes are encrypted `gp3` volumes with `DeleteOnTermination = true`:

- Meetings Hybrid and workers: 200 GiB.
- Masters and AI Services: 500 GiB.

AMI channel selection is `dev` for masters and `prod` for all other nodes. AMI IDs resolve from `deployments/aws-ami-catalog.json` unless locally overridden. Set `ai_services_ami_id` in `local.auto.tfvars` to use a GPU-specific image for every AI Services node; leave it `null` to retain the production-catalog fallback.

Changing `ai_services_ami_id` while an AI node exists replaces that EC2 instance and its root volume. Its separately managed ENI, private IP, security group, and IAM profile are retained. Create a fresh registration code and a new saved plan before applying an AMI change.

## 8. Render cloud-init

Terraform renders custom Zoom Node configuration containing:

- FQDN and generated administrator password.
- Fresh registration code.
- Exact guest interface name from `instance-catalog.json`.
- Static private addresses, subnet prefix, gateway, and VPC DNS server.

Changing bootstrap data does not modify a running node because user data is ignored after creation. A fresh registration code requires replacing the affected EC2 instance so cloud-init runs again.

## 9. Add the Kubernetes HA VIP

The provider-neutral input declares `10.40.0.250` on master 1:

```hcl
control_plane_virtual_ip = {
  address         = "10.40.0.250"
  assignment_mode = "node"
  owner_node_key  = "kubernetes_master-01"
}
```

On a new deployment, Terraform adds the VIP to the master's ENI. For an adopted ENI whose private-address list is protected by lifecycle rules, perform the one-time assignment and refresh state:

```bash
aws ec2 assign-private-ip-addresses \
  --region us-east-1 \
  --network-interface-id <master-1-eni-id> \
  --private-ip-addresses 10.40.0.250

terraform apply -refresh-only
```

Terraform assigns the AWS address but does not configure kube-vip inside the appliance. Configure kube-vip to advertise `10.40.0.250` separately.

## 10. Plan and apply

```bash
terraform plan -out=tfplan
terraform show tfplan
terraform apply tfplan
```

Apply the saved plan before the registration code expires. Do not reuse a saved plan after changing the registration code.

To rerun cloud-init with a fresh code, replace only the required instances:

```bash
terraform plan \
  -replace='module.zoom_node.module.node.aws_instance.zoom_node["meetings_hybrid-01"]' \
  -out=tfplan

terraform apply tfplan
```

Use additional `-replace` arguments for other stable node keys. ENIs, private IPs, EIPs, security groups, IAM profiles, and S3 storage remain separate resources and are retained.

## 11. Verify the deployment

```bash
terraform plan -detailed-exitcode
terraform output instance_ids
terraform output node_private_ips
terraform output node_public_ips
terraform output control_plane_virtual_ip
```

Exit code `0` from the final plan means the deployment is converged. Also confirm:

- EC2 system and instance checks are `ok`.
- Public EIPs have association IDs and expected private-address mappings.
- The NAT Gateway is `available` and private routes are active.
- The Zoom portal shows every node registered.
- Public node local-admin status reports the node agent as installed.

