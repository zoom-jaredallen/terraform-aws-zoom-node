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
      instance_types = ["c6i.2xlarge"]
    }
  }
}

mock_provider "random" {}

variables {
  environment_name  = "contract"
  domain_name       = "example.com"
  registration_code = "ABCDEFGHIJKLMNOP"
  node_password     = "ZoomNode1!"

  workloads = {
    meetings_hybrid = {
      enabled  = true
      capacity = 500
    }
  }

  source_cidrs = {
    remote_management_1 = ["192.0.2.10/32"]
  }

  aws = {
    image_id           = "ami-0123456789abcdef0"
    availability_zones = ["us-west-2a"]
  }
}

run "plan_meetings_hybrid_defaults" {
  command = plan

  assert {
    condition     = output.workload_node_counts["MeetingsHybrid"] == 2
    error_message = "Meetings Hybrid capacity 500 must produce the two-node minimum."
  }

  assert {
    condition     = length(aws_instance.zoom_node) == 2
    error_message = "The plan must contain two Meetings Hybrid EC2 instances."
  }

  assert {
    condition     = length(aws_eip.zoom_node) == 10
    error_message = "Each Meetings Hybrid node must receive five Elastic IPs."
  }

  assert {
    condition     = aws_instance.zoom_node["meetings_hybrid-01"].metadata_options[0].http_tokens == "required"
    error_message = "Zoom Node instances must require IMDSv2."
  }

  assert {
    condition     = length(aws_vpc_security_group_egress_rule.zoom_node) == 1
    error_message = "The backward-compatible default must retain one allow-all egress rule."
  }
}

run "plan_advanced_node_overrides" {
  command = plan

  variables {
    workloads = {}
    node_groups = {
      control_plane = {
        count                                = 1
        role                                 = "kubernetes_master"
        hostname_prefix                      = "control"
        instance_type                        = "m7i.2xlarge"
        image_id                             = "ami-0fedcba9876543210"
        root_volume_gb                       = 500
        private_ips_per_node                 = 1
        elastic_ips_per_node                 = 1
        private_ip_start_offset              = 20
        subnet_tier                          = "public"
        purchase_option                      = "spot"
        source_dest_check                    = false
        metadata_http_put_response_hop_limit = 3
        security_profile                     = "kubernetes_master"
        iam_profile_key                      = "kubernetes"
      }
    }
  }

  assert {
    condition     = aws_instance.zoom_node["control_plane-01"].ami == "ami-0fedcba9876543210"
    error_message = "An advanced node image override must take precedence over the catalog."
  }

  assert {
    condition     = aws_network_interface.zoom_node["control_plane-01"].source_dest_check == false
    error_message = "The control-plane source/destination check override must be preserved."
  }

  assert {
    condition     = aws_instance.zoom_node["control_plane-01"].metadata_options[0].http_put_response_hop_limit == 3
    error_message = "The per-node IMDS hop limit must be preserved."
  }

  assert {
    condition     = aws_instance.zoom_node["control_plane-01"].instance_market_options[0].market_type == "spot"
    error_message = "The advanced node purchase option must produce a Spot request."
  }
}

run "reject_unrestricted_management" {
  command = plan

  variables {
    source_cidrs = {
      remote_management_1 = ["0.0.0.0/0"]
    }
  }

  expect_failures = [terraform_data.validation]
}

run "plan_explicit_deny_all_egress" {
  command = plan

  variables {
    aws = {
      image_id           = "ami-0123456789abcdef0"
      availability_zones = ["us-west-2a"]
      security_group_egress_profiles = {
        MeetingsHybrid = "deny_all"
      }
    }
  }

  assert {
    condition     = length(aws_vpc_security_group_egress_rule.zoom_node) == 0
    error_message = "deny_all must create no outbound security-group rules."
  }
}

run "plan_workload_specific_egress" {
  command = plan

  variables {
    aws = {
      image_id           = "ami-0123456789abcdef0"
      availability_zones = ["us-west-2a"]
      security_group_egress_profiles = {
        MeetingsHybrid = "workload_specific"
      }
    }
  }

  assert {
    condition     = length(aws_vpc_security_group_egress_rule.zoom_node) == 2
    error_message = "Meetings Hybrid workload-specific egress must include Zoom HTTPS and media rules."
  }
}

run "plan_legacy_least_privilege_egress" {
  command = plan

  variables {
    enable_least_privilege_egress = true
  }

  assert {
    condition     = length(aws_vpc_security_group_egress_rule.zoom_node) == 2
    error_message = "The deprecated least-privilege boolean must retain its workload-specific behavior."
  }
}

run "reject_invalid_egress_profile" {
  command = plan

  variables {
    aws = {
      image_id           = "ami-0123456789abcdef0"
      availability_zones = ["us-west-2a"]
      security_group_egress_profiles = {
        MeetingsHybrid = "invalid"
      }
    }
  }

  expect_failures = [terraform_data.validation]
}

run "plan_storage_and_encryption_hardening" {
  command = plan

  variables {
    workloads = {
      hybrid_recording = {
        enabled  = true
        capacity = 30
      }
    }

    hybrid_recording_s3_bucket_name = "zoom-node-contract-recordings"
    hybrid_recording_s3_bucket_mode = "create_new"

    aws = {
      image_id                                                         = "ami-0123456789abcdef0"
      availability_zones                                               = ["us-west-2a"]
      root_volume_kms_key_id                                           = "arn:aws:kms:us-west-2:123456789012:key/11111111-1111-1111-1111-111111111111"
      cloudwatch_log_retention_days                                    = 90
      cloudwatch_log_kms_key_id                                        = "arn:aws:kms:us-west-2:123456789012:key/22222222-2222-2222-2222-222222222222"
      hybrid_recording_s3_actions                                      = ["s3:GetObject", "s3:PutObject", "s3:ListBucket"]
      hybrid_recording_s3_kms_key_arn                                  = "arn:aws:kms:us-west-2:123456789012:key/33333333-3333-3333-3333-333333333333"
      hybrid_recording_s3_versioning_enabled                           = true
      hybrid_recording_s3_lifecycle_expiration_days                    = 365
      hybrid_recording_s3_lifecycle_noncurrent_version_expiration_days = 30
    }
  }

  assert {
    condition     = aws_instance.zoom_node["hybrid_recording-01"].root_block_device[0].kms_key_id == "arn:aws:kms:us-west-2:123456789012:key/11111111-1111-1111-1111-111111111111"
    error_message = "The supplied EBS KMS key must be applied to Zoom Node root volumes."
  }

  assert {
    condition     = aws_cloudwatch_log_group.zoom_node["hybrid_recording-01"].retention_in_days == 90
    error_message = "CloudWatch Logs retention must use the configured value."
  }

  assert {
    condition     = aws_cloudwatch_log_group.zoom_node["hybrid_recording-01"].kms_key_id == "arn:aws:kms:us-west-2:123456789012:key/22222222-2222-2222-2222-222222222222"
    error_message = "The supplied CloudWatch Logs KMS key must be applied."
  }

  assert {
    condition     = one(one(aws_s3_bucket_server_side_encryption_configuration.hybrid_recording[0].rule).apply_server_side_encryption_by_default).sse_algorithm == "aws:kms"
    error_message = "The managed Hybrid Recording bucket must use AWS KMS when a key is supplied."
  }

  assert {
    condition     = length(aws_s3_bucket_versioning.hybrid_recording) == 1 && length(aws_s3_bucket_lifecycle_configuration.hybrid_recording) == 1
    error_message = "Configured Hybrid Recording versioning and lifecycle resources must be planned."
  }

  assert {
    condition     = contains(jsondecode(aws_iam_role_policy.hybrid_recording_s3["HybridRecording"].policy).Statement[0].Action, "s3:PutObject")
    error_message = "Hybrid Recording IAM must use the configured granular S3 actions."
  }

  assert {
    condition     = contains(jsondecode(aws_iam_role_policy.hybrid_recording_s3["HybridRecording"].policy).Statement[1].Action, "kms:GenerateDataKey")
    error_message = "Hybrid Recording IAM must include scoped KMS data-key permissions."
  }
}
