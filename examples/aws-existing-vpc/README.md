# AWS Existing VPC Example

This root module demonstrates a public Zoom Node deployment in an existing AWS VPC and subnet set. It enables Meetings Hybrid and Meeting Survivability and generates a compliant Zoom Node password.

Running this example creates cost-bearing EC2 instances, EBS volumes, Elastic IPs, workload security groups, IAM resources, and CloudWatch log groups. It does not create or take ownership of the supplied VPC and subnets. Confirm that their routing and available address space meet the module requirements before applying.

## Use

```bash
cd terraform/examples/aws-existing-vpc
cp terraform.tfvars.example local.auto.tfvars
# Replace the registration code, VPC ID, and subnet ID placeholders.

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

Terraform state contains rendered cloud-init, including the registration code and generated password. Treat state and saved plans as sensitive data. Use an encrypted, access-controlled remote backend with locking for shared or production deployments.
