module "zoom_node" {
  source = "../.."

  environment_name       = "demo"
  domain_name            = "lab.zoomdemos.com"
  deployment_mode        = "public_cloud"
  network_mode           = "create_new"
  registration_code      = var.registration_code
  generate_node_password = true

  source_cidrs = {
    zoom_clients        = ["0.0.0.0/0"]
    zoom_cloud          = ["0.0.0.0/0"]
    remote_management_1 = ["38.99.100.7/32"]
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
    hybrid_recording = {
      enabled  = true
      capacity = 30
    }
  }

  hybrid_recording_s3_bucket_name = "demo-lab-zoom-node-recordings"
  hybrid_recording_s3_bucket_mode = "create_new"

  aws = {
    vpc_cidr           = "10.0.0.0/16"
    availability_zones = ["us-west-2a"]
    instance_tags = {
      PatchGroup  = "Linux"
      appliance   = "true"
      cost_center = "solution_engineering"
    }
  }

  tags = {
    Owner       = "solution-engineering"
    CostCenter  = "solution_engineering"
    Environment = "Demo"
  }
}
