# AWS Single-Node Smoke Example

This is the smallest live AWS exercise of the reusable module. It creates a new VPC and one public Meeting Survivability node with a generated password.

Running it creates cost-bearing EC2, EBS, Elastic IP, CloudWatch, IAM, security-group, and VPC resources. Use it for short validation runs and destroy it when testing is complete.

## Use

```bash
cd examples/aws-smoke-single-node
cp terraform.tfvars.example local.auto.tfvars
# Replace the registration code placeholder and optionally select aws_region.

terraform init
terraform plan
terraform apply
terraform output -raw generated_node_password
```

Authenticate with AWS SSO, an AWS profile, or environment variables before running Terraform. `local.auto.tfvars` is ignored by Git and loaded automatically.

## Destroy

```bash
terraform destroy
```

Terraform state contains rendered cloud-init, including the registration code and generated password. Treat state and saved plans as sensitive data. Use an encrypted, access-controlled remote backend with locking for shared use.
