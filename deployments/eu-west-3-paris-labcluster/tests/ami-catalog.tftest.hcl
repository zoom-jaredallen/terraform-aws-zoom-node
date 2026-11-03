mock_provider "aws" {
  mock_data "aws_region" {
    defaults = {
      region = "eu-west-3"
    }
  }

  mock_data "aws_availability_zones" {
    defaults = {
      names = ["eu-west-3a", "eu-west-3b", "eu-west-3c"]
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
      instance_types = ["mocked-instance-type"]
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
  registration_code = "ABCDEFGHIJKLMNOP"
  aws_region        = "eu-west-3"
}

run "use_regional_catalog_defaults" {
  command = plan

  assert {
    condition     = local.effective_prod_ami_id == local.deployment_ami_catalog.prod["eu-west-3"]
    error_message = "The deployment must resolve its default production AMI from the regional deployment catalog."
  }

  assert {
    condition     = local.effective_dev_ami_id == local.deployment_ami_catalog.dev["eu-west-3"]
    error_message = "The deployment must resolve its default development AMI from the regional deployment catalog."
  }

  assert {
    condition     = length(module.zoom_node.instance_ids) == 8
    error_message = "The Paris topology must plan exactly eight Zoom Node instances."
  }

  assert {
    condition     = alltrue([for request in module.zoom_node.capacity_preflight_requests : request.region == "eu-west-3" && request.availability_zone == "eu-west-3b" && request.market_type == "on-demand"])
    error_message = "Every Paris node group must use On-Demand capacity in eu-west-3b."
  }
}

run "prefer_explicit_ami_overrides" {
  command = plan

  variables {
    prod_ami_id = "ami-01111111111111111"
    dev_ami_id  = "ami-02222222222222222"
  }

  assert {
    condition     = local.effective_prod_ami_id == "ami-01111111111111111"
    error_message = "An explicit production AMI must override the deployment catalog."
  }

  assert {
    condition     = local.effective_dev_ami_id == "ami-02222222222222222"
    error_message = "An explicit development AMI must override the deployment catalog."
  }
}
