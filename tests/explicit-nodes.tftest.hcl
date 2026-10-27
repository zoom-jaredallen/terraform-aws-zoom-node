mock_provider "aws" {
  mock_data "aws_region" {
    defaults = { region = "ap-northeast-1" }
  }
  mock_data "aws_availability_zones" {
    defaults = { names = ["ap-northeast-1a"] }
  }
  mock_data "aws_servicequotas_service_quota" {
    defaults = { value = 150 }
  }
  mock_data "aws_eips" {
    defaults = { public_ips = [] }
  }
  mock_data "aws_ec2_instance_type_offerings" {
    defaults = { instance_types = ["g6.12xlarge", "g6.2xlarge"] }
  }
  mock_data "aws_vpc" {
    defaults = { cidr_block = "10.2.0.0/16" }
  }
  mock_data "aws_subnet" {
    defaults = { cidr_block = "10.2.101.0/24" }
  }
}

mock_provider "random" {}

variables {
  environment_name  = "explicit"
  domain_name       = "example.com"
  registration_code = "ABCDEFGHIJKLMNOP"
  node_password     = "ZoomNode1!"
  network_mode      = "use_existing"
  source_cidrs = {
    remote_management_1 = ["192.0.2.10/32"]
  }
  aws = {
    existing_vpc_id     = "vpc-0123456789abcdef0"
    existing_subnet_ids = ["subnet-0123456789abcdef0"]
  }
}

run "plan_explicit_nodes_with_external_dependencies" {
  command = plan

  override_data {
    target = module.network.data.aws_vpc.existing[0]
    values = { cidr_block = "10.2.0.0/16" }
  }

  override_data {
    target = module.network.data.aws_subnet.existing["subnet-0123456789abcdef0"]
    values = { cidr_block = "10.2.101.0/24" }
  }

  variables {
    explicit_nodes = {
      "jp01worker1-ap-northeast-1a" = {
        node_name                 = "jp01worker1-ap-northeast-1a"
        fqdn                      = "jp01worker1-ap-northeast-1a"
        role                      = "ai_services"
        instance_type             = "g6.12xlarge"
        image_id                  = "ami-0f31cf9510e341030"
        root_volume_gb            = 500
        private_ips               = ["10.2.101.241"]
        subnet_tier               = "public"
        source_dest_check         = true
        security_group_ids        = ["sg-0123456789abcdef0"]
        iam_instance_profile_name = "ZoomNodeS3Access"
      }
      "jp01worker2-ap-northeast-1a" = {
        role               = "ai_services"
        instance_type      = "g6.2xlarge"
        image_id           = "ami-0f31cf9510e341030"
        root_volume_gb     = 500
        private_ips        = ["10.2.101.242"]
        subnet_tier        = "public"
        source_dest_check  = false
        security_group_ids = ["sg-0123456789abcdef0"]
      }
    }
  }

  assert {
    condition     = keys(module.node.instances) == ["jp01worker1-ap-northeast-1a", "jp01worker2-ap-northeast-1a"]
    error_message = "Explicit-node map keys must remain the stable EC2 resource keys."
  }
  assert {
    condition     = module.node.instances["jp01worker1-ap-northeast-1a"].instance_type == "g6.12xlarge" && module.node.instances["jp01worker2-ap-northeast-1a"].instance_type == "g6.2xlarge"
    error_message = "Each explicit node must retain its exact instance type."
  }
  assert {
    condition     = module.node.instances["jp01worker1-ap-northeast-1a"].iam_instance_profile == "ZoomNodeS3Access"
    error_message = "An external IAM instance profile must be preserved."
  }
  assert {
    condition     = module.node.network_interfaces["jp01worker1-ap-northeast-1a"].private_ips == toset(["10.2.101.241"]) && module.node.network_interfaces["jp01worker2-ap-northeast-1a"].private_ips == toset(["10.2.101.242"])
    error_message = "Explicit private IP lists must be preserved exactly."
  }
  assert {
    condition     = module.node.network_interfaces["jp01worker1-ap-northeast-1a"].security_groups == toset(["sg-0123456789abcdef0"]) && !module.node.network_interfaces["jp01worker2-ap-northeast-1a"].source_dest_check
    error_message = "External security groups and source/destination-check settings must be preserved."
  }
  assert {
    condition     = module.node.eip_count == 0
    error_message = "Explicit nodes default to zero Elastic IPs."
  }
  assert {
    condition     = strcontains(nonsensitive(base64decode(module.node.instances["jp01worker1-ap-northeast-1a"].user_data_base64)), "hostname: jp01worker1-ap-northeast-1a")
    error_message = "An explicitly preserved appliance hostname must be rendered without a domain suffix."
  }
}

run "reject_duplicate_explicit_node_key" {
  command = plan
  override_data {
    target = module.network.data.aws_subnet.existing["subnet-0123456789abcdef0"]
    values = { cidr_block = "10.2.101.0/24" }
  }
  variables {
    node_groups = {
      duplicate = {
        count                   = 1
        role                    = "ai_services"
        hostname_prefix         = "duplicate"
        instance_type           = "g6.2xlarge"
        image_id                = "ami-0f31cf9510e341030"
        root_volume_gb          = 500
        private_ip_start_offset = 10
        subnet_tier             = "public"
        security_profile        = "kubernetes_worker"
        iam_profile_key         = "workers"
      }
    }
    explicit_nodes = {
      "duplicate-01" = {
        role               = "ai_services"
        instance_type      = "g6.2xlarge"
        image_id           = "ami-0f31cf9510e341030"
        root_volume_gb     = 500
        private_ips        = ["10.2.101.20"]
        subnet_tier        = "public"
        security_group_ids = ["sg-0123456789abcdef0"]
      }
    }
  }
  expect_failures = [terraform_data.validation]
}

run "reject_empty_explicit_private_ips" {
  command = plan
  override_data {
    target = module.network.data.aws_subnet.existing["subnet-0123456789abcdef0"]
    values = { cidr_block = "10.2.101.0/24" }
  }
  variables {
    explicit_nodes = {
      empty = {
        role               = "ai_services"
        instance_type      = "g6.2xlarge"
        image_id           = "ami-0f31cf9510e341030"
        root_volume_gb     = 500
        private_ips        = []
        subnet_tier        = "public"
        security_group_ids = ["sg-0123456789abcdef0"]
      }
    }
  }
  expect_failures = [terraform_data.validation]
}

run "reject_explicit_ip_outside_subnet" {
  command = plan
  override_data {
    target = module.network.data.aws_subnet.existing["subnet-0123456789abcdef0"]
    values = { cidr_block = "10.2.101.0/24" }
  }
  variables {
    explicit_nodes = {
      outside = {
        role               = "ai_services"
        instance_type      = "g6.2xlarge"
        image_id           = "ami-0f31cf9510e341030"
        root_volume_gb     = 500
        private_ips        = ["10.3.101.20"]
        subnet_tier        = "public"
        security_group_ids = ["sg-0123456789abcdef0"]
      }
    }
  }
  expect_failures = [terraform_data.validation]
}

run "reject_explicit_eips_without_private_ips" {
  command = plan
  override_data {
    target = module.network.data.aws_subnet.existing["subnet-0123456789abcdef0"]
    values = { cidr_block = "10.2.101.0/24" }
  }
  variables {
    explicit_nodes = {
      excessive_eips = {
        role                 = "ai_services"
        instance_type        = "g6.2xlarge"
        image_id             = "ami-0f31cf9510e341030"
        root_volume_gb       = 500
        private_ips          = ["10.2.101.20"]
        elastic_ips_per_node = 2
        subnet_tier          = "public"
        security_group_ids   = ["sg-0123456789abcdef0"]
      }
    }
  }
  expect_failures = [terraform_data.validation]
}

run "reject_mixed_explicit_security_ownership" {
  command = plan
  override_data {
    target = module.network.data.aws_subnet.existing["subnet-0123456789abcdef0"]
    values = { cidr_block = "10.2.101.0/24" }
  }
  variables {
    explicit_nodes = {
      mixed_security = {
        role               = "ai_services"
        instance_type      = "g6.2xlarge"
        image_id           = "ami-0f31cf9510e341030"
        root_volume_gb     = 500
        private_ips        = ["10.2.101.20"]
        subnet_tier        = "public"
        security_profile   = "kubernetes_worker"
        security_group_ids = ["sg-0123456789abcdef0"]
      }
    }
  }
  expect_failures = [terraform_data.validation]
}

run "reject_mixed_explicit_iam_ownership" {
  command = plan
  override_data {
    target = module.network.data.aws_subnet.existing["subnet-0123456789abcdef0"]
    values = { cidr_block = "10.2.101.0/24" }
  }
  variables {
    explicit_nodes = {
      mixed_iam = {
        role                      = "ai_services"
        instance_type             = "g6.2xlarge"
        image_id                  = "ami-0f31cf9510e341030"
        root_volume_gb            = 500
        private_ips               = ["10.2.101.20"]
        subnet_tier               = "public"
        security_group_ids        = ["sg-0123456789abcdef0"]
        iam_profile_key           = "workers"
        iam_instance_profile_name = "ZoomNodeS3Access"
      }
    }
  }
  expect_failures = [terraform_data.validation]
}
