locals {
  hybrid_recording_enabled = contains(keys(local.enabled_workloads), "HybridRecording")
  managed_node_group_s3_buckets = {
    for access_key, access in var.aws.s3_bucket_access : access_key => access
    if access.mode == "create_new"
  }
  node_group_s3_lifecycle_buckets = {
    for access_key, access in local.managed_node_group_s3_buckets : access_key => access
    if access.lifecycle_expiration_days != null || access.lifecycle_noncurrent_version_expiration_days != null
  }
  node_group_s3_policy_record_list = flatten([
    for access_key, access in var.aws.s3_bucket_access : [
      for profile_key in access.iam_profile_keys : {
        key         = "${access_key}:${profile_key}"
        access_key  = access_key
        profile_key = profile_key
        bucket_name = access.bucket_name
        actions     = access.actions
        kms_key_arn = access.kms_key_arn
      }
    ]
  ])
  node_group_s3_policy_records = { for record in local.node_group_s3_policy_record_list : record.key => record }
}
