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

  mock_data "aws_ami" {
    defaults = {
      architecture = "x86_64"
      state        = "available"
    }
  }
}

mock_provider "random" {}

variables {
  environment_name  = "images"
  domain_name       = "example.com"
  registration_code = "ABCDEFGHIJKLMNOP"
  node_password     = "ZoomNode1!"

  image_ids = {
    prod = {
      us-west-2 = "ami-0a111111111111111"
    }
    dev = {
      us-west-2 = "ami-0b222222222222222"
    }
  }

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
    condition     = module.node.instances["meeting_survivability-01"].ami == "ami-0a111111111111111"
    error_message = "The production channel must resolve the customer's regional production AMI."
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
    condition     = module.node.instances["meeting_survivability-01"].ami == "ami-0b222222222222222"
    error_message = "The development channel must resolve the customer's regional development AMI."
  }
}

run "reject_missing_customer_image" {
  command = plan

  variables {
    image_ids = {}
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

  expect_failures = [terraform_data.validation]
}

run "plan_legacy_global_image_override" {
  command = plan

  variables {
    image_ids = {}
    workloads = {
      meeting_survivability = {
        enabled    = true
        node_count = 1
      }
    }
    aws = {
      image_id           = "ami-0c333333333333333"
      availability_zones = ["us-west-2a"]
    }
  }

  assert {
    condition     = module.node.instances["meeting_survivability-01"].ami == "ami-0c333333333333333"
    error_message = "The existing aws.image_id compatibility override must remain functional."
  }
}

run "plan_legacy_regional_image_override" {
  command = plan

  variables {
    image_ids = {}
    workloads = {
      meeting_survivability = {
        enabled    = true
        node_count = 1
      }
    }
    aws = {
      image_ids = {
        us-west-2 = "ami-0d444444444444444"
      }
      availability_zones = ["us-west-2a"]
    }
  }

  assert {
    condition     = module.node.instances["meeting_survivability-01"].ami == "ami-0d444444444444444"
    error_message = "The existing aws.image_ids compatibility map must remain functional."
  }
}

run "plan_workload_image_override_precedence" {
  command = plan

  variables {
    workloads = {
      meeting_survivability = {
        enabled    = true
        node_count = 1
        image_id   = "ami-0e555555555555555"
      }
    }
    aws = {
      image_id           = "ami-0f666666666666666"
      availability_zones = ["us-west-2a"]
    }
  }

  assert {
    condition     = module.node.instances["meeting_survivability-01"].ami == "ami-0e555555555555555"
    error_message = "A workload image_id must take precedence over customer and legacy global images."
  }
}

run "reject_malformed_resolved_image" {
  command = plan

  variables {
    image_ids = {}
    workloads = {
      meeting_survivability = {
        enabled    = true
        node_count = 1
      }
    }
    aws = {
      image_id           = "not-an-ami"
      availability_zones = ["us-west-2a"]
    }
  }

  expect_failures = [terraform_data.validation]
}

run "reject_non_x86_64_image" {
  command = plan

  override_data {
    target = data.aws_ami.selected
    values = {
      architecture = "arm64"
      state        = "available"
    }
  }

  variables {
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

  expect_failures = [terraform_data.validation]
}

run "reject_unavailable_image" {
  command = plan

  override_data {
    target = data.aws_ami.selected
    values = {
      architecture = "x86_64"
      state        = "disabled"
    }
  }

  variables {
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

  expect_failures = [terraform_data.validation]
}

run "plan_deduplicated_image_validation" {
  command = plan

  variables {
    workloads = {
      meetings_hybrid = {
        enabled  = true
        capacity = 500
      }
    }
    aws = {
      availability_zones = ["us-west-2a"]
    }
  }

  assert {
    condition     = length(data.aws_ami.selected) == 1
    error_message = "Nodes sharing an AMI must produce one plan-time EC2 image lookup."
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

  expect_failures = [check.deprecated_instance_family_nic_map]

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
    condition     = module.node.instances["meetings_hybrid-01"].ami == "ami-0a111111111111111" && module.node.instances["meetings_hybrid-02"].ami == "ami-07777777777777777"
    error_message = "A stable-key AMI override must affect only the selected node."
  }

  assert {
    condition     = module.node.network_interfaces["meetings_hybrid-01"].source_dest_check && !module.node.network_interfaces["meetings_hybrid-02"].source_dest_check
    error_message = "A stable-key source/destination override must affect only the selected node."
  }
}

run "plan_instance_create_timeout_precedence" {
  command = plan

  variables {
    node_groups = {
      workers = {
        count                   = 2
        role                    = "kubernetes_worker"
        hostname_prefix         = "worker"
        instance_type           = "m7i.2xlarge"
        image_id                = "ami-08888888888888888"
        root_volume_gb          = 200
        private_ip_start_offset = 20
        subnet_tier             = "public"
        security_profile        = "kubernetes_worker"
        iam_profile_key         = "kubernetes"
        instance_create_timeout = "7m"
      }
    }
    aws = {
      availability_zones      = ["us-west-2a"]
      instance_create_timeout = "10m"
      node_instance_create_timeouts = {
        workers-02 = "3m"
      }
    }
  }

  assert {
    condition     = module.node.instances["workers-01"].instance_create_timeout == "7m" && module.node.instances["workers-02"].instance_create_timeout == "3m"
    error_message = "Group timeouts must override the global default and stable-node overrides must take highest precedence."
  }

  assert {
    condition     = output.capacity_preflight_requests == [{ availability_zone = "us-west-2a", instance_count = 2, instance_type = "m7i.2xlarge", market_type = "on-demand", region = "us-west-2" }]
    error_message = "The capacity manifest must group identical requests and contain only its five nonsensitive fields."
  }
}

run "plan_default_instance_create_timeout" {
  command = plan

  variables {
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
    condition     = module.node.instances["meeting_survivability-01"].instance_create_timeout == "10m"
    error_message = "EC2 instance creation must default to a ten-minute timeout."
  }
}

run "reject_malformed_instance_create_timeout" {
  command = plan

  variables {
    workloads = {
      meeting_survivability = {
        enabled    = true
        node_count = 1
      }
    }
    aws = {
      availability_zones      = ["us-west-2a"]
      instance_create_timeout = "soon"
    }
  }

  expect_failures = [terraform_data.validation]
}

run "reject_unknown_instance_create_timeout_key" {
  command = plan

  variables {
    workloads = {
      meeting_survivability = {
        enabled    = true
        node_count = 1
      }
    }
    aws = {
      availability_zones = ["us-west-2a"]
      node_instance_create_timeouts = {
        missing-01 = "5m"
      }
    }
  }

  expect_failures = [terraform_data.validation]
}
