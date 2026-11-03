# AWS New VPC Example

This root module demonstrates a public Zoom Node deployment in a new AWS VPC. It enables Meetings Hybrid, Meeting Survivability, and Hybrid Recording, creates the Hybrid Recording S3 bucket, and generates a compliant Zoom Node password.

Running this example creates cost-bearing EC2 instances, EBS volumes, Elastic IPs, CloudWatch log groups, networking resources, and an S3 bucket. Review the selected workloads, CIDRs, region, AMIs, and current AWS quotas before applying it.

## Use

```bash
cd examples/aws-new-vpc
cp terraform.tfvars.example local.auto.tfvars
# Replace the registration code and customer-accessible AMI placeholders.

terraform init
terraform plan -out=tfplan
# Optional: use when current EC2 capacity is a concern.
../../scripts/check-ec2-capacity.sh --terraform-plan tfplan
terraform apply tfplan
terraform output -raw generated_node_password
rm -f tfplan
```

The Capacity Manager preflight is optional and Terraform can plan or apply without it. It is intended for Spot, GPU-backed, unusually large, multi-node, or single-AZ requests. See [Optional capacity preflight](../../docs/prerequisites.md#optional-capacity-preflight) for its Unified Operations and Capacity Manager requirements.

Authenticate with AWS SSO, an AWS profile, or environment variables before running Terraform. `local.auto.tfvars` is ignored by Git and loaded automatically.

## Destroy

```bash
terraform destroy
```

Terraform state contains rendered cloud-init, including the registration code and generated password. Treat state and saved plans as sensitive data. Use an encrypted, access-controlled remote backend with locking for shared or production deployments.
