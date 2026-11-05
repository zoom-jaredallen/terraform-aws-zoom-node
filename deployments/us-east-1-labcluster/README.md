# US East 1 Lab Cluster

See [`RUNBOOK.md`](RUNBOOK.md) for the resource-by-resource Terraform procedure, bootstrap replacement workflow, and verification commands.

This configuration defines a temporary nine-node Zoom Node lab in `us-east-1`. It creates one Meetings Hybrid node, three Kubernetes masters, four private Kubernetes workers, one private On-Demand AI Services node, a new VPC, one NAT Gateway, and an encrypted S3 bucket.

CPU nodes default to `us-east-1a`. After AWS reported insufficient `g6.12xlarge` capacity there, AI Services was assigned a dedicated `10.40.2.0/24` private subnet in `us-east-1b`. This preserves the existing CPU nodes when the GPU placement changes. The Kubernetes masters use the development image channel; Meetings Hybrid, workers, and AI Services use production. Both channels resolve from [`../aws-ami-catalog.json`](../aws-ami-catalog.json). Wait for both copied AMIs to become `available` before planning:

```bash
aws ec2 describe-images \
  --region us-east-1 \
  --image-ids ami-012f8220608dbc5fb ami-084ef071e238208e7 \
  --query 'Images[].{ImageId:ImageId,State:State}' \
  --output table
```

Set `ai_services_ami_id` when the GPU appliance requires an image different from the standard production image. The explicit AI Services AMI takes precedence over the production catalog; leaving it `null` preserves the catalog fallback. Terraform validates that the selected image is visible, available in `us-east-1`, and uses `x86_64` architecture.

The deployment currently consumes the in-repository module because it requires the managed-EIP quota fix added after `v0.4.1`. Pin it to the next immutable release after that release is committed, tagged, and published. The deployment creates a new environment and must not be used to infer ownership of unrelated infrastructure.

## Before Planning

The topology needs 84 Standard On-Demand vCPUs, 48 On-Demand G/VT vCPUs, and nine Elastic IPs: five for Meetings Hybrid, three for the masters, and one for the NAT Gateway. Check the account quotas:

```bash
aws service-quotas get-service-quota --region us-east-1 --service-code ec2 --quota-code L-1216C47A
aws service-quotas get-service-quota --region us-east-1 --service-code ec2 --quota-code L-DB2E81BA
aws service-quotas get-service-quota --region us-east-1 --service-code ec2 --quota-code L-0263D0A3
aws ec2 describe-addresses --region us-east-1
```

The account-qualified S3 bucket name is intended to avoid global naming collisions. Change `s3_bucket_name` before apply if the name is already owned elsewhere.

The AWS provider allows only account `626657815993` by default. From this deployment directory, run `set -a; source ../../.env; set +a` and verify `aws sts get-caller-identity` before every plan or apply. An unsourced shell may otherwise use credentials from another AWS profile.

## Capacity Check

Capacity checking does not need a live registration code. Create a disposable plan with a format-valid placeholder, run the optional preflight, and never apply this plan:

```bash
cd deployments/us-east-1-labcluster
terraform init -upgrade
TF_VAR_registration_code=ABCDEFGHIJKLMNOP terraform plan -out=capacity.tfplan
../../scripts/check-ec2-capacity.sh \
  --terraform-plan capacity.tfplan \
  --capacity-manager-region us-west-2
```

The Capacity Manager preflight is optional and does not reserve capacity. Current `g6.12xlarge` supportability may be low. If the GPU returns `InsufficientInstanceCapacity`, change only `ai_services_availability_zone`; the existing CPU nodes and their subnets remain unchanged.

## Final Plan And Apply

Create the ignored local variables file. Obtain a fresh registration code only when you are ready to create and apply the final plan:

```bash
cd deployments/us-east-1-labcluster
cp terraform.tfvars.example local.auto.tfvars
# Edit local.auto.tfvars and replace registration_code.
terraform plan -out=tfplan
# Review promptly, then apply while the registration code is still valid.
terraform apply tfplan
```

Never apply `capacity.tfplan`; it contains a placeholder registration code. If the real registration code expires before apply, obtain a new code and create a new final plan rather than applying the old saved plan.

The node password is generated automatically. Retrieve it after apply with:

```bash
terraform output -raw generated_node_password
```

`local.auto.tfvars`, state, and saved plans are ignored because registration data and rendered user data are sensitive. Authenticate with AWS SSO, a profile, or environment variables rather than placing AWS credentials in Terraform variables.

## Lab Limitations

This topology is intentionally temporary and is not highly available. The three masters have independent public EIPs but share `us-east-1a`. Workers and AI Services have no EIPs and use the NAT Gateway for outbound traffic. The GPU subnet in `us-east-1b` uses the NAT Gateway in `us-east-1a`, which introduces cross-AZ data-processing charges. Terraform does not configure Kubernetes, kube-vip, or application routing inside the appliances.

The S3 bucket deliberately has `force_destroy = false`. Before destroying the temporary environment, preserve any required data and empty the bucket so Terraform can delete it:

```bash
aws s3 rm s3://zoomnode-use1-labcluster-626657815993 --recursive
terraform destroy
```
