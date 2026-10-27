module "zoom_node" {
  source = "../.."

  environment_name       = "demo"
  domain_name            = "lab.example.com"
  deployment_mode        = "public_cloud"
  network_mode           = "create_new"
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
    hybrid_recording = {
      enabled  = true
      capacity = 30
    }
  }

  aws = {
    vpc_cidr           = "10.0.0.0/16"
    availability_zones = ["us-west-2a"]
    s3_bucket_access = {
      hybrid_recording = {
        bucket_name      = "demo-lab-zoom-node-recordings"
        mode             = "create_new"
        iam_profile_keys = ["HybridRecording"]
      }
    }
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
