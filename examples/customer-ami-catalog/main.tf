module "zoom_node" {
  source = "../.."

  environment_name       = "customer-images"
  domain_name            = "lab.example.com"
  deployment_mode        = "public_cloud"
  network_mode           = "create_new"
  registration_code      = var.registration_code
  generate_node_password = true
  image_channel          = var.image_channel

  image_ids = {
    prod = { (var.aws_region) = var.prod_ami_id }
    dev  = var.dev_ami_id == null ? {} : { (var.aws_region) = var.dev_ami_id }
  }

  source_cidrs = {
    remote_management_1 = ["203.0.113.10/32"]
    internal_traffic    = ["10.0.0.0/16"]
  }

  workloads = {
    meeting_survivability = {
      enabled    = true
      node_count = 1
    }
  }

  aws = {
    vpc_cidr           = "10.0.0.0/16"
    availability_zones = [var.availability_zone]
  }
}
