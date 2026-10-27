mock_provider "aws" {
  mock_data "aws_region" {
    defaults = {
      region = "us-west-2"
    }
  }

  mock_data "aws_availability_zones" {
    defaults = {
      names = ["us-west-2a", "us-west-2b"]
    }
  }

  mock_data "aws_servicequotas_service_quota" {
    defaults = {
      value = 150
    }
  }

  mock_data "aws_eips" {
    defaults = {
      public_ips = []
    }
  }

  mock_data "aws_ec2_instance_type_offerings" {
    defaults = {
      instance_types = ["c6i.2xlarge", "c6i.xlarge", "custom.xlarge", "m7i.2xlarge"]
    }
  }
}

mock_provider "random" {}

variables {
  environment_name  = "images"
  domain_name       = "example.com"
  registration_code = "ABCDEFGHIJKLMNOP"
  node_password     = "ZoomNode1!"

  source_cidrs = {
    remote_management_1 = ["192.0.2.10/32"]
  }
}

run "plan_prod_image_catalog" {
  command = plan

  variables {
    image_channel = "prod"
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

  assert {
    condition     = module.node.instances["meeting_survivability-01"].ami == "ami-0d693e77e13176e99"
    error_message = "The production channel must resolve the regional production AMI catalog entry."
  }
}

run "plan_dev_image_catalog" {
  command = plan

  variables {
    image_channel = "dev"
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

  assert {
    condition     = module.node.instances["meeting_survivability-01"].ami == "ami-08254730bfaf2cb38"
    error_message = "The development channel must resolve the regional development AMI catalog entry."
  }
}

run "plan_catalog_nic_mappings" {
  command = plan

  variables {
    node_groups = {
      legacy_nic = {
        count                   = 1
        role                    = "kubernetes_worker"
        hostname_prefix         = "legacy"
        instance_type           = "c6i.2xlarge"
        image_id                = "ami-01111111111111111"
        root_volume_gb          = 200
        private_ip_start_offset = 20
        subnet_tier             = "public"
        security_profile        = "kubernetes_worker"
        iam_profile_key         = "kubernetes"
      }
      predictable_nic = {
        count                   = 1
        role                    = "kubernetes_worker"
        hostname_prefix         = "predictable"
        instance_type           = "m7i.2xlarge"
        image_id                = "ami-02222222222222222"
        root_volume_gb          = 200
        private_ip_start_offset = 40
        subnet_tier             = "public"
        security_profile        = "kubernetes_worker"
        iam_profile_key         = "kubernetes"
      }
    }
    aws = {
      availability_zones = ["us-west-2a"]
    }
  }

  assert {
    condition     = strcontains(nonsensitive(base64decode(module.node.instances["legacy_nic-01"].user_data_base64)), "    ens5:")
    error_message = "The c6i catalog mapping must render ens5 in cloud-init."
  }

  assert {
    condition     = strcontains(nonsensitive(base64decode(module.node.instances["predictable_nic-01"].user_data_base64)), "    enp39s0:")
    error_message = "The m7i catalog mapping must render enp39s0 in cloud-init."
  }
}

run "plan_nic_mapping_overrides" {
  command = plan

  variables {
    node_groups = {
      exact = {
        count                   = 1
        role                    = "kubernetes_worker"
        hostname_prefix         = "exact"
        instance_type           = "m7i.2xlarge"
        image_id                = "ami-03333333333333333"
        root_volume_gb          = 200
        private_ip_start_offset = 20
        subnet_tier             = "public"
        security_profile        = "kubernetes_worker"
        iam_profile_key         = "kubernetes"
      }
      family = {
        count                   = 1
        role                    = "kubernetes_worker"
        hostname_prefix         = "family"
        instance_type           = "custom.xlarge"
        image_id                = "ami-04444444444444444"
        root_volume_gb          = 200
        private_ip_start_offset = 40
        subnet_tier             = "public"
        security_profile        = "kubernetes_worker"
        iam_profile_key         = "kubernetes"
      }
    }
    aws = {
      availability_zones = ["us-west-2a"]
      network_interface_names_by_instance_type = {
        "m7i.2xlarge" = "eth9"
      }
      network_interface_names_by_instance_family = {
        custom = "eth7"
      }
    }
  }

  assert {
    condition     = strcontains(nonsensitive(base64decode(module.node.instances["exact-01"].user_data_base64)), "    eth9:")
    error_message = "An exact instance-type NIC override must take precedence over the catalog."
  }

  assert {
    condition     = strcontains(nonsensitive(base64decode(module.node.instances["family-01"].user_data_base64)), "    eth7:")
    error_message = "An instance-family NIC override must support otherwise unmapped instance types."
  }
}

run "plan_global_nic_override" {
  command = plan

  variables {
    node_groups = {
      first = {
        count                   = 1
        role                    = "kubernetes_worker"
        hostname_prefix         = "first"
        instance_type           = "c6i.2xlarge"
        image_id                = "ami-05555555555555555"
        root_volume_gb          = 200
        private_ip_start_offset = 20
        subnet_tier             = "public"
        security_profile        = "kubernetes_worker"
        iam_profile_key         = "kubernetes"
      }
      second = {
        count                   = 1
        role                    = "kubernetes_worker"
        hostname_prefix         = "second"
        instance_type           = "m7i.2xlarge"
        image_id                = "ami-06666666666666666"
        root_volume_gb          = 200
        private_ip_start_offset = 40
        subnet_tier             = "public"
        security_profile        = "kubernetes_worker"
        iam_profile_key         = "kubernetes"
      }
    }
    aws = {
      availability_zones     = ["us-west-2a"]
      network_interface_name = "eth-global"
    }
  }

  assert {
    condition     = alltrue([for node_key in ["first-01", "second-01"] : strcontains(nonsensitive(base64decode(module.node.instances[node_key].user_data_base64)), "    eth-global:")])
    error_message = "The global NIC override must take precedence for every node."
  }
}

run "plan_per_node_overrides" {
  command = plan

  variables {
    workloads = {
      meetings_hybrid = {
        enabled  = true
        capacity = 500
      }
    }
    node_image_ids = {
      meetings_hybrid-02 = "ami-07777777777777777"
    }
    aws = {
      availability_zones = ["us-west-2a"]
      node_source_dest_check = {
        meetings_hybrid-02 = false
      }
    }
  }

  assert {
    condition     = module.node.instances["meetings_hybrid-01"].ami == "ami-0d693e77e13176e99" && module.node.instances["meetings_hybrid-02"].ami == "ami-07777777777777777"
    error_message = "A stable-key AMI override must affect only the selected node."
  }

  assert {
    condition     = module.node.network_interfaces["meetings_hybrid-01"].source_dest_check && !module.node.network_interfaces["meetings_hybrid-02"].source_dest_check
    error_message = "A stable-key source/destination override must affect only the selected node."
  }
}
