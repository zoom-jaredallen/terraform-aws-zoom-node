output "iam_instance_profile_names" { value = { for key, profile in aws_iam_instance_profile.zoom_node : key => profile.name } }
output "s3_bucket_names" { value = { for key, bucket in aws_s3_bucket.node_group : key => bucket.bucket } }
output "test_contract" {
  value = {
    hybrid_bucket_count           = length(aws_s3_bucket.hybrid_recording)
    hybrid_public_block_count     = length(aws_s3_bucket_public_access_block.hybrid_recording)
    hybrid_encryption_count       = length(aws_s3_bucket_server_side_encryption_configuration.hybrid_recording)
    hybrid_encryption_algorithm   = try(one(one(aws_s3_bucket_server_side_encryption_configuration.hybrid_recording[0].rule).apply_server_side_encryption_by_default).sse_algorithm, null)
    hybrid_versioning_count       = length(aws_s3_bucket_versioning.hybrid_recording)
    hybrid_lifecycle_count        = length(aws_s3_bucket_lifecycle_configuration.hybrid_recording)
    hybrid_policy_count           = length(aws_iam_role_policy.hybrid_recording_s3)
    hybrid_policies               = { for key, policy in aws_iam_role_policy.hybrid_recording_s3 : key => policy.policy }
    node_group_buckets            = { for key, bucket in aws_s3_bucket.node_group : key => bucket.bucket }
    node_group_public_block_count = length(aws_s3_bucket_public_access_block.node_group)
    node_group_encryption_count   = length(aws_s3_bucket_server_side_encryption_configuration.node_group)
    node_group_versioning_count   = length(aws_s3_bucket_versioning.node_group)
    node_group_lifecycle_count    = length(aws_s3_bucket_lifecycle_configuration.node_group)
    node_group_policies           = { for key, policy in aws_iam_role_policy.node_group_s3 : key => policy.policy }
  }
}
