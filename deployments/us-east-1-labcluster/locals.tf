locals {
  deployment_ami_catalog = jsondecode(file("${path.module}/../aws-ami-catalog.json"))

  catalog_prod_ami_id = try(trimspace(local.deployment_ami_catalog.prod[var.aws_region]), "")
  catalog_dev_ami_id  = try(trimspace(local.deployment_ami_catalog.dev[var.aws_region]), "")

  effective_prod_ami_id = var.prod_ami_id != null && trimspace(var.prod_ami_id) != "" ? trimspace(var.prod_ami_id) : local.catalog_prod_ami_id
  effective_dev_ami_id  = var.dev_ami_id != null && trimspace(var.dev_ami_id) != "" ? trimspace(var.dev_ami_id) : local.catalog_dev_ami_id
}
