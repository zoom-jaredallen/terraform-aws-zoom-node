check "deprecated_enable_least_privilege_egress" {
  assert {
    condition     = !var.enable_least_privilege_egress
    error_message = "enable_least_privilege_egress is deprecated and will be removed in v1.0.0; use aws.security_group_egress_profiles instead."
  }
}

check "deprecated_subnet_cidrs" {
  assert {
    condition     = length(var.aws.subnet_cidrs) == 0
    error_message = "aws.subnet_cidrs is deprecated and will be removed in v1.0.0; use aws.public_subnet_cidrs instead."
  }
}

check "deprecated_instance_family_nic_map" {
  assert {
    condition     = length(var.aws.network_interface_names_by_instance_family) == 0
    error_message = "aws.network_interface_names_by_instance_family is deprecated and will be removed in v1.0.0; use instance-catalog.json or aws.network_interface_names_by_instance_type instead."
  }
}

check "deprecated_public_ipv4_on_boot" {
  assert {
    condition     = !var.aws.enable_public_ipv4_on_boot
    error_message = "aws.enable_public_ipv4_on_boot is deprecated and will be removed in v1.0.0; Zoom Nodes use explicit ENIs and Elastic IP associations."
  }
}

check "deprecated_hybrid_recording_s3_inputs" {
  assert {
    condition = (
      !local.dedicated_hybrid_recording_s3_configured &&
      var.hybrid_recording_s3_bucket_mode == "use_existing" &&
      var.aws.hybrid_recording_s3_actions == toset(["s3:*"]) &&
      var.aws.hybrid_recording_s3_kms_key_arn == null &&
      !var.aws.hybrid_recording_s3_versioning_enabled &&
      var.aws.hybrid_recording_s3_lifecycle_expiration_days == null &&
      var.aws.hybrid_recording_s3_lifecycle_noncurrent_version_expiration_days == null
    )
    error_message = "Dedicated hybrid_recording_s3_* inputs are deprecated and will be removed in v1.0.0; use aws.s3_bucket_access[\"hybrid_recording\"] targeting HybridRecording instead."
  }
}
