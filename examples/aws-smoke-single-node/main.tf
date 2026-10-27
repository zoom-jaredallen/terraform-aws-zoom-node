module "zoom_node" {
  source = "../.."

  environment_name       = "smoke"
  domain_name            = "lab.example.com"
  deployment_mode        = "public_cloud"
  network_mode           = "create_new"
  registration_code      = var.registration_code
  generate_node_password = true

  source_cidrs = {
    zoom_clients        = ["0.0.0.0/0"]
    zoom_cloud          = ["0.0.0.0/0"]
    remote_management_1 = ["203.0.113.10/32"]
    remote_management_2 = ["198.51.100.10/32"]
    internal_traffic    = ["10.0.0.0/16"]
    nfs                 = []
    sbc                 = []
  }

  workloads = {
    meeting_survivability = {
      enabled    = true
      node_count = 1
    }
  }

  aws = {
    vpc_cidr           = "10.0.0.0/16"
    availability_zones = ["us-west-2a"]
    instance_tags = {
      PatchGroup  = "Linux"
      appliance   = "true"
      cost_center = "infrastructure"
    }
  }

  tags = {
    Owner       = "platform@example.com"
    CostCenter  = "infrastructure"
    Environment = "Smoke"
  }
}
