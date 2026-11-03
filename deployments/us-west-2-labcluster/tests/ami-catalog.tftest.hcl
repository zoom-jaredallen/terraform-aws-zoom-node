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
}

run "use_regional_catalog_defaults" {
  command = plan

  assert {
    condition     = local.effective_prod_ami_id == local.deployment_ami_catalog.prod["us-west-2"]
    error_message = "The deployment must resolve its default production AMI from the regional deployment catalog."
  }

  assert {
    condition     = local.effective_dev_ami_id == local.deployment_ami_catalog.dev["us-west-2"]
    error_message = "The deployment must resolve its default development AMI from the regional deployment catalog."
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
