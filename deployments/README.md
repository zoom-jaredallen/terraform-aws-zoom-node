# Maintained Deployments

These environment-specific Terraform roots are tracked because they document stable node identities, networking, AMIs, and upgrade behavior. Each root consumes an immutable module release and is validated by `scripts/check-repository.sh`.

Terraform state is intentionally not stored in this repository. Copying a deployment configuration does not transfer ownership of existing infrastructure. Before planning, applying, or destroying an existing environment from one of these paths, migrate its authoritative state to an encrypted, access-controlled remote backend and configure that backend in the deployment root. An empty state can propose duplicate infrastructure or conflict with existing AWS resources.

The following files remain local and are ignored by Git:

- `.terraform/`
- `*.tfstate` and backups
- saved plans such as `tfplan`, `*.tfplan`, and `*.plan`
- `.env` files
- `local.auto.tfvars` and `*.tfvars.local`
- `.migration/` artifacts

Dependency lockfiles and `terraform.tfvars.example` files are tracked. Never place live registration codes, node passwords, or AWS credentials in committed files.

Customer-owned AMIs shared by maintained deployments are recorded by channel and Region in [`aws-ami-catalog.json`](aws-ami-catalog.json). Deployment variables may override a catalog value when testing a replacement image. The reusable module's own `image-catalog.json` remains empty so published releases do not assume access to private customer images.

For a new or safely migrated deployment:

```bash
terraform init -upgrade
terraform plan -out=tfplan
# Optional: useful for Spot, GPU, large, or AZ-constrained requests.
../../scripts/check-ec2-capacity.sh --terraform-plan tfplan
# Review the saved plan before applying it.
terraform apply tfplan
```

The Capacity Manager preflight is optional and Terraform does not depend on it. Use it when Spot, GPU-backed, unusually large, multi-node, or single-AZ requests make current physical capacity a concern. It requires Capacity Manager and AWS Unified Operations; see [Optional capacity preflight](../docs/prerequisites.md#optional-capacity-preflight). Scores are point-in-time guidance and do not reserve or guarantee EC2 capacity.
