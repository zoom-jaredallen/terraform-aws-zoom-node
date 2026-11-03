# Getting Started

This guide deploys the module from a caller-owned Terraform root. Start with [`examples/aws-smoke-single-node`](../examples/aws-smoke-single-node) for the smallest live AWS test.

## 1. Check prerequisites

Complete the [prerequisites checklist](prerequisites.md). In particular, obtain a customer-accessible Zoom Node AMI for the target AWS account and Region, a fresh 16-character registration code, suitable AWS quotas, and management CIDRs that are narrower than `0.0.0.0/0`.

Authenticate Terraform through AWS IAM Identity Center, an AWS profile, or the standard AWS environment variables. Do not commit credentials or place them in Terraform input files.

## 2. Choose a deployment pattern

| Pattern | Starting point |
|---|---|
| Smallest live validation | [`examples/aws-smoke-single-node`](../examples/aws-smoke-single-node) |
| Module-managed VPC and subnets | [`examples/aws-new-vpc`](../examples/aws-new-vpc) |
| Existing VPC and subnets | [`examples/aws-existing-vpc`](../examples/aws-existing-vpc) |
| Customer-managed production/development AMIs | [`examples/customer-ami-catalog`](../examples/customer-ami-catalog) |

Pin the module to an immutable release tag:

```hcl
module "zoom_node" {
  source = "git::https://github.com/zoom-jaredallen/terraform-aws-zoom-node.git?ref=v0.4.1"

  domain_name            = "lab.example.com"
  registration_code      = var.registration_code
  generate_node_password = true

  image_ids = {
    prod = {
      us-west-2 = var.prod_ami_id
    }
  }

  source_cidrs = {
    remote_management_1 = ["203.0.113.10/32"]
  }

  workloads = {
    meeting_survivability = {
      enabled    = true
      node_count = 1
    }
  }

  aws = {
    availability_zones = ["us-west-2a"]
  }
}
```

## 3. Store local values safely

Copy the example values into an ignored local file:

```bash
cp terraform.tfvars.example local.auto.tfvars
```

Use `local.auto.tfvars` for non-secret environment settings and sensitive Terraform variables when working locally. For automation, prefer CI secret injection or `TF_VAR_registration_code` and `TF_VAR_node_password`. Terraform state and saved plans contain rendered cloud-init and must be treated as sensitive even when variables are marked `sensitive`.

## 4. Plan and preflight

The following commands assume the current directory is one of this repository's `examples/*` roots, where the capacity script is available two directories above it:

```bash
terraform init
terraform fmt -check
terraform validate
terraform plan -out=tfplan
# Optional: useful for Spot, GPU, large, or AZ-constrained requests.
../../scripts/check-ec2-capacity.sh --terraform-plan tfplan --minimum-score medium
```

The capacity command is optional; skip it for routine plans or when the account does not meet the [optional capacity-preflight prerequisites](prerequisites.md#optional-capacity-preflight). It is intended for Spot, GPU-backed, unusually large, multi-node, or single-AZ requests where current physical capacity is a concern. External caller roots must invoke the script from a local checkout of this module. It scores point-in-time supportability but does not reserve capacity or guarantee launch success.

Review the saved plan for:

- the expected node count, instance types, Availability Zones, private IPs, and Elastic IPs;
- no unexpected `-/+` replacements;
- workload-specific security rules and intended egress profiles;
- S3, IAM, KMS, and NAT resources that create additional ownership or cost;
- a customer-visible AMI for every node.

## 5. Apply and verify

```bash
terraform apply tfplan
terraform output node_fqdns
terraform output node_private_ips
terraform output node_public_ips
terraform output -raw generated_node_password
rm -f tfplan
```

Confirm that each node registers with Zoom and that the required workload traffic is reachable. A registration code is short-lived; obtain a new code before any later operation that creates or replaces a node.

## 6. Destroy test environments

```bash
terraform destroy
```

Terraform still evaluates required root inputs during destroy. Keep the ignored variable file available, or supply syntactically valid sensitive values through `TF_VAR_*`. If Terraform reports no managed objects, verify that the command is running from the same root, workspace, and backend used for the apply.
