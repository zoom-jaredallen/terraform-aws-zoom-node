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
      instance_types = ["m6i.6xlarge", "t3.large"]
    }
  }
}

mock_provider "random" {}

variables {
  environment_name  = "storage"
  domain_name       = "example.com"
  registration_code = "ABCDEFGHIJKLMNOP"
  node_password     = "ZoomNode1!"

  source_cidrs = {
    remote_management_1 = ["192.0.2.10/32"]
  }
}

run "plan_hybrid_recording_create_new_bucket" {
  command = plan

  expect_failures = [check.deprecated_hybrid_recording_s3_inputs]

  variables {
    workloads = {
      hybrid_recording = {
        enabled  = true
        capacity = 30
      }
    }
    hybrid_recording_s3_bucket_name = "zoom-node-contract-managed-recordings"
    hybrid_recording_s3_bucket_mode = "create_new"
    aws = {
      availability_zones = ["us-west-2a"]
    }
  }

  assert {
    condition     = module.storage_access.test_contract.hybrid_bucket_count == 1 && module.storage_access.test_contract.hybrid_public_block_count == 1 && module.storage_access.test_contract.hybrid_encryption_count == 1
    error_message = "Hybrid Recording create_new mode must own a protected, encrypted S3 bucket."
  }

  assert {
    condition     = module.storage_access.test_contract.hybrid_policy_count == 1
    error_message = "Hybrid Recording must grant its instance role access to the configured bucket."
  }
}

run "plan_hybrid_recording_use_existing_bucket" {
  command = plan

  expect_failures = [check.deprecated_hybrid_recording_s3_inputs]

  variables {
    workloads = {
      hybrid_recording = {
        enabled  = true
        capacity = 30
      }
    }
    hybrid_recording_s3_bucket_name = "zoom-node-contract-existing-recordings"
    hybrid_recording_s3_bucket_mode = "use_existing"
    aws = {
      availability_zones = ["us-west-2a"]
    }
  }

  assert {
    condition     = module.storage_access.test_contract.hybrid_bucket_count == 0 && module.storage_access.test_contract.hybrid_public_block_count == 0 && module.storage_access.test_contract.hybrid_encryption_count == 0
    error_message = "Hybrid Recording use_existing mode must not take ownership of S3 bucket controls."
  }

  assert {
    condition     = contains(jsondecode(module.storage_access.test_contract.hybrid_policies["HybridRecording"]).Statement[0].Resource, "arn:aws:s3:::zoom-node-contract-existing-recordings/*")
    error_message = "Hybrid Recording use_existing mode must still grant access to the selected bucket objects."
  }
}

run "plan_advanced_s3_bucket_modes" {
  command = plan

  variables {
    node_groups = {
      archive = {
        count                   = 1
        role                    = "kubernetes_worker"
        hostname_prefix         = "archive"
        instance_type           = "t3.large"
        image_id                = "ami-08888888888888888"
        root_volume_gb          = 200
        private_ip_start_offset = 20
        subnet_tier             = "public"
        security_profile        = "kubernetes_worker"
        iam_profile_key         = "archive"
      }
    }
    aws = {
      availability_zones = ["us-west-2a"]
      s3_bucket_access = {
        managed = {
          bucket_name               = "zoom-node-contract-managed-archive"
          mode                      = "create_new"
          iam_profile_keys          = ["archive"]
          actions                   = ["s3:GetObject", "s3:PutObject", "s3:ListBucket"]
          versioning_enabled        = true
          lifecycle_expiration_days = 365
        }
        existing = {
          bucket_name      = "zoom-node-contract-existing-archive"
          mode             = "use_existing"
          iam_profile_keys = ["archive"]
          actions          = ["s3:GetObject", "s3:ListBucket"]
        }
      }
    }
  }

  assert {
    condition     = length(module.storage_access.test_contract.node_group_buckets) == 1 && module.storage_access.test_contract.node_group_buckets["managed"] == "zoom-node-contract-managed-archive"
    error_message = "Advanced S3 access must create only buckets configured with create_new mode."
  }

  assert {
    condition     = module.storage_access.test_contract.node_group_versioning_count == 1 && module.storage_access.test_contract.node_group_lifecycle_count == 1
    error_message = "Managed advanced buckets must apply configured versioning and lifecycle controls."
  }

  assert {
    condition     = length(module.storage_access.test_contract.node_group_policies) == 2 && contains(jsondecode(module.storage_access.test_contract.node_group_policies["existing:archive"]).Statement[0].Resource, "arn:aws:s3:::zoom-node-contract-existing-archive/*")
    error_message = "Both managed and existing advanced buckets must grant their configured profile scoped access."
  }
}
