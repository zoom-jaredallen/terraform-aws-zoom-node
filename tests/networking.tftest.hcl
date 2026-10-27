mock_provider "aws" {
  mock_data "aws_region" {
    defaults = {
      region = "us-west-2"
    }
  }

  mock_data "aws_availability_zones" {
    defaults = {
      names = ["us-west-2a", "us-west-2b", "us-west-2c"]
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
      instance_types = ["c6i.2xlarge", "c6i.xlarge", "t3.large"]
    }
  }

  mock_data "aws_vpc" {
    defaults = {
      cidr_block = "10.50.0.0/16"
    }
  }

  mock_data "aws_subnet" {
    defaults = {
      cidr_block        = "10.50.10.0/24"
      availability_zone = "us-west-2a"
    }
  }
}

mock_provider "random" {}

variables {
  environment_name  = "network"
  domain_name       = "example.com"
  registration_code = "ABCDEFGHIJKLMNOP"
  node_password     = "ZoomNode1!"

  source_cidrs = {
    remote_management_1 = ["192.0.2.10/32"]
    internal_traffic    = ["10.0.0.0/8"]
  }
}

run "plan_create_new_single_az" {
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
    condition     = module.network.test_contract.vpc_count == 1 && length(module.network.test_contract.public_subnets) == 1
    error_message = "create_new single_az must create one VPC and one public subnet."
  }

  assert {
    condition     = local.node_records["meeting_survivability-01"].subnet_tier == "public" && local.node_records["meeting_survivability-01"].subnet_index == 0
    error_message = "A single-AZ workload must select the first managed public subnet."
  }
}

run "plan_create_new_dual_az" {
  command = plan

  variables {
    availability_zone_config = "dual_az"
    workloads = {
      meetings_hybrid = {
        enabled  = true
        capacity = 500
      }
    }
    aws = {
      availability_zones = ["us-west-2a", "us-west-2b"]
    }
  }

  assert {
    condition     = length(module.network.test_contract.public_subnets) == 2 && module.network.test_contract.public_subnets[0].availability_zone == "us-west-2a" && module.network.test_contract.public_subnets[1].availability_zone == "us-west-2b"
    error_message = "dual_az must create one public subnet in each requested Availability Zone."
  }

  assert {
    condition     = local.node_records["meetings_hybrid-01"].subnet_index == 0 && local.node_records["meetings_hybrid-02"].subnet_index == 1
    error_message = "Dual-AZ workload nodes must be distributed across the two managed subnets."
  }
}

run "plan_use_existing_network" {
  command = plan

  variables {
    network_mode = "use_existing"
    workloads = {
      meeting_survivability = {
        enabled    = true
        node_count = 1
      }
    }
    aws = {
      existing_vpc_id     = "vpc-0123456789abcdef0"
      existing_subnet_ids = ["subnet-0123456789abcdef0"]
    }
  }

  assert {
    condition     = module.network.test_contract.vpc_count == 0 && length(module.network.test_contract.public_subnets) == 0
    error_message = "use_existing must not create a VPC or public subnet."
  }

  assert {
    condition     = output.vpc_id == "vpc-0123456789abcdef0" && length(output.subnet_ids) == 1 && output.subnet_ids[0] == "subnet-0123456789abcdef0"
    error_message = "use_existing must expose the supplied VPC and subnet IDs."
  }

  assert {
    condition     = module.node.network_interfaces["meeting_survivability-01"].subnet_id == "subnet-0123456789abcdef0"
    error_message = "Existing-network nodes must attach to the supplied subnet."
  }
}

run "plan_private_nodes_with_nat_gateway" {
  command = plan

  variables {
    node_groups = {
      control = {
        count                   = 1
        role                    = "kubernetes_master"
        hostname_prefix         = "control"
        instance_type           = "t3.large"
        root_volume_gb          = 200
        elastic_ips_per_node    = 1
        private_ip_start_offset = 10
        subnet_tier             = "public"
        security_profile        = "kubernetes_master"
        iam_profile_key         = "kubernetes"
      }
      workers = {
        count                   = 2
        role                    = "kubernetes_worker"
        hostname_prefix         = "worker"
        instance_type           = "t3.large"
        root_volume_gb          = 200
        private_ip_start_offset = 20
        subnet_tier             = "private"
        security_profile        = "kubernetes_worker"
        iam_profile_key         = "kubernetes"
      }
    }
    aws = {
      availability_zones = ["us-west-2a"]
      create_nat_gateway = true
    }
  }

  assert {
    condition     = module.network.test_contract.nat_gateway_count == 1 && module.network.test_contract.nat_eip_count == 1
    error_message = "A private node topology with NAT enabled must create one NAT Gateway and EIP."
  }

  assert {
    condition     = length(module.network.test_contract.public_subnets) == 1 && module.network.test_contract.private_subnet_count == 1
    error_message = "The mixed topology must create one public and one private subnet in single-AZ mode."
  }

  assert {
    condition     = local.node_records["control-01"].subnet_tier == "public" && local.node_records["workers-01"].subnet_tier == "private"
    error_message = "Public and private node groups must attach to their selected subnet tiers."
  }

  assert {
    condition     = module.network.test_contract.private_default_route_cidr == "0.0.0.0/0"
    error_message = "The private route table must send default IPv4 traffic through the managed NAT Gateway."
  }
}

run "plan_global_spot_workloads" {
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
      purchase_option    = "spot"
    }
  }

  assert {
    condition     = module.node.instances["meeting_survivability-01"].market_type == "spot"
    error_message = "The global Spot option must apply to standard workload instances."
  }
}

run "reject_overlapping_static_ip_ranges" {
  command = plan

  variables {
    node_groups = {
      first = {
        count                   = 1
        role                    = "kubernetes_worker"
        hostname_prefix         = "first"
        instance_type           = "t3.large"
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
        instance_type           = "t3.large"
        root_volume_gb          = 200
        private_ip_start_offset = 20
        subnet_tier             = "public"
        security_profile        = "kubernetes_worker"
        iam_profile_key         = "kubernetes"
      }
    }
    aws = {
      availability_zones = ["us-west-2a"]
    }
  }

  expect_failures = [terraform_data.validation]
}

run "reject_static_ip_subnet_exhaustion" {
  command = plan

  variables {
    node_groups = {
      oversized = {
        count                   = 1
        role                    = "kubernetes_worker"
        hostname_prefix         = "oversized"
        instance_type           = "t3.large"
        root_volume_gb          = 200
        private_ips_per_node    = 5
        private_ip_start_offset = 10
        subnet_tier             = "public"
        security_profile        = "kubernetes_worker"
        iam_profile_key         = "kubernetes"
      }
    }
    aws = {
      availability_zones  = ["us-west-2a"]
      public_subnet_cidrs = ["10.0.0.0/28"]
    }
  }

  expect_failures = [terraform_data.validation]
}
