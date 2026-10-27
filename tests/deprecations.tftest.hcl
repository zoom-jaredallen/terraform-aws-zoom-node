mock_provider "aws" {
  mock_data "aws_region" { defaults = { region = "us-west-2" } }
  mock_data "aws_availability_zones" { defaults = { names = ["us-west-2a"] } }
  mock_data "aws_servicequotas_service_quota" { defaults = { value = 150 } }
  mock_data "aws_eips" { defaults = { public_ips = [] } }
  mock_data "aws_ec2_instance_type_offerings" { defaults = { instance_types = ["m6i.6xlarge"] } }
}

mock_provider "random" {}

variables {
  environment_name  = "deprecations"
  domain_name       = "example.com"
  registration_code = "ABCDEFGHIJKLMNOP"
  node_password     = "ZoomNode1!"
  source_cidrs = {
    remote_management_1 = ["192.0.2.10/32"]
  }
}

run "plan_generic_hybrid_recording_s3_access" {
  command = plan

  variables {
    workloads = {
      hybrid_recording = {
        enabled  = true
        capacity = 30
      }
    }
    aws = {
      availability_zones = ["us-west-2a"]
      s3_bucket_access = {
        hybrid_recording = {
          bucket_name               = "zoom-node-contract-generic-recordings"
          mode                      = "create_new"
          iam_profile_keys          = ["HybridRecording"]
          actions                   = ["s3:GetObject", "s3:PutObject", "s3:ListBucket"]
          versioning_enabled        = true
          lifecycle_expiration_days = 365
        }
      }
    }
  }

  assert {
    condition     = module.storage_access.test_contract.node_group_buckets["hybrid_recording"] == "zoom-node-contract-generic-recordings"
    error_message = "Generic Hybrid Recording S3 access must create the configured bucket."
  }

  assert {
    condition     = module.storage_access.test_contract.node_group_public_block_count == 1 && module.storage_access.test_contract.node_group_encryption_count == 1
    error_message = "Generic Hybrid Recording buckets must receive the standard public-access and encryption controls."
  }

  assert {
    condition     = contains(jsondecode(module.storage_access.test_contract.node_group_policies["hybrid_recording:HybridRecording"]).Statement[0].Resource, "arn:aws:s3:::zoom-node-contract-generic-recordings/*")
    error_message = "Generic Hybrid Recording S3 access must target the HybridRecording IAM profile."
  }
}

run "reject_conflicting_hybrid_recording_s3_inputs" {
  command = plan

  variables {
    workloads = {
      hybrid_recording = {
        enabled  = true
        capacity = 30
      }
    }
    hybrid_recording_s3_bucket_name = "zoom-node-contract-legacy-recordings"
    aws = {
      availability_zones = ["us-west-2a"]
      s3_bucket_access = {
        hybrid_recording = {
          bucket_name      = "zoom-node-contract-generic-recordings"
          iam_profile_keys = ["HybridRecording"]
        }
      }
    }
  }

  expect_failures = [terraform_data.validation, check.deprecated_hybrid_recording_s3_inputs]
}

run "warn_deprecated_enable_least_privilege_egress" {
  command = plan
  variables { enable_least_privilege_egress = true }
  expect_failures = [check.deprecated_enable_least_privilege_egress]
}

run "warn_deprecated_subnet_cidrs" {
  command = plan
  variables { aws = { subnet_cidrs = ["10.0.0.0/24"] } }
  expect_failures = [check.deprecated_subnet_cidrs]
}

run "warn_deprecated_instance_family_nic_map" {
  command = plan
  variables { aws = { network_interface_names_by_instance_family = { g6 = "enp39s0" } } }
  expect_failures = [check.deprecated_instance_family_nic_map]
}

run "warn_deprecated_public_ipv4_on_boot" {
  command = plan
  variables { aws = { enable_public_ipv4_on_boot = true } }
  expect_failures = [check.deprecated_public_ipv4_on_boot]
}

run "warn_deprecated_hybrid_recording_s3_inputs" {
  command = plan
  variables { hybrid_recording_s3_bucket_name = "zoom-node-contract-legacy-recordings" }
  expect_failures = [check.deprecated_hybrid_recording_s3_inputs]
}
