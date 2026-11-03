# Customer AMI Catalog

Zoom Node AMIs are private and regional. Obtain production and optional development images from Zoom, then ensure each image is visible to the AWS account running Terraform by copying it into that account or having the owner share it.

Set the image IDs in `terraform.tfvars`. This example creates one Meeting Survivability node and uses the production channel by default. Set `image_channel = "dev"` only when the optional development AMI has also been supplied.

An AMI copied to another account or region receives a new ID. Terraform validates the selected image in the provider's active account and region during planning.

```bash
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform plan -out=tfplan
# Optional: use when current EC2 capacity is a concern.
../../scripts/check-ec2-capacity.sh --terraform-plan tfplan
rm -f tfplan
```

The Capacity Manager preflight is optional. It is intended for Spot, GPU-backed, unusually large, multi-node, or single-AZ requests and is not required to validate the AMI catalog. See [Optional capacity preflight](../../docs/prerequisites.md#optional-capacity-preflight) for its Unified Operations and Capacity Manager requirements.

Planning creates no resources. Applying this example creates billable AWS infrastructure.
