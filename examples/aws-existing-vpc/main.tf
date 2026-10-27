module "zoom_node" {
  source = "../.."

  environment_name       = "demo"
  domain_name            = "lab.example.com"
  deployment_mode        = "public_cloud"
  network_mode           = "use_existing"
  registration_code      = var.registration_code
  generate_node_password = true

  source_cidrs = {
    zoom_clients        = ["0.0.0.0/0"]
    zoom_cloud          = ["0.0.0.0/0"]
    remote_management_1 = ["203.0.113.10/32"]
    remote_management_2 = []
    internal_traffic    = ["10.0.0.0/16"]
    nfs                 = ["10.10.0.0/16"]
    sbc                 = []
  }

  workloads = {
    meetings_hybrid = {
      enabled  = true
      capacity = 500
    }
    meeting_survivability = {
      enabled    = true
      node_count = 1
    }
  }

  aws = {
    existing_vpc_id     = var.existing_vpc_id
    existing_subnet_ids = var.existing_subnet_ids
    instance_tags = {
      PatchGroup  = "Linux"
      appliance   = "true"
      cost_center = "infrastructure"
    }
  }

  tags = {
    Owner       = "platform-engineering"
    CostCenter  = "infrastructure"
    Environment = "Demo"
  }
}
