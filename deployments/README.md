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

For a new or safely migrated deployment:

```bash
terraform init -upgrade
terraform plan -out=tfplan
../../scripts/check-ec2-capacity.sh --terraform-plan tfplan
# Review the saved plan before applying it.
terraform apply tfplan
```

Capacity Manager scores are point-in-time guidance and do not reserve EC2 capacity.
