resource "aws_s3_bucket" "hybrid_recording" {
  count  = var.hybrid_recording_enabled && var.hybrid_recording_bucket_mode == "create_new" ? 1 : 0
  bucket = var.hybrid_recording_bucket_name
  tags   = merge(var.common_tags, { Name = var.hybrid_recording_bucket_name, Workload = "HybridRecording" })
}

resource "aws_s3_bucket_public_access_block" "hybrid_recording" {
  count                   = var.hybrid_recording_enabled && var.hybrid_recording_bucket_mode == "create_new" ? 1 : 0
  bucket                  = aws_s3_bucket.hybrid_recording[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "hybrid_recording" {
  count  = var.hybrid_recording_enabled && var.hybrid_recording_bucket_mode == "create_new" ? 1 : 0
  bucket = aws_s3_bucket.hybrid_recording[0].id
  rule {
    bucket_key_enabled = var.hybrid_recording_kms_key_arn != null
    apply_server_side_encryption_by_default {
      kms_master_key_id = var.hybrid_recording_kms_key_arn
      sse_algorithm     = var.hybrid_recording_kms_key_arn != null ? "aws:kms" : "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "hybrid_recording" {
  count  = var.hybrid_recording_enabled && var.hybrid_recording_bucket_mode == "create_new" && var.hybrid_recording_versioning_enabled ? 1 : 0
  bucket = aws_s3_bucket.hybrid_recording[0].id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_lifecycle_configuration" "hybrid_recording" {
  count  = var.hybrid_recording_enabled && var.hybrid_recording_bucket_mode == "create_new" && (var.hybrid_recording_lifecycle_expiration_days != null || var.hybrid_recording_lifecycle_noncurrent_version_expiration_days != null) ? 1 : 0
  bucket = aws_s3_bucket.hybrid_recording[0].id
  rule {
    id     = "zoom-node-managed-retention"
    status = "Enabled"
    filter {}
    dynamic "expiration" {
      for_each = var.hybrid_recording_lifecycle_expiration_days != null ? [var.hybrid_recording_lifecycle_expiration_days] : []
      content { days = expiration.value }
    }
    dynamic "noncurrent_version_expiration" {
      for_each = var.hybrid_recording_lifecycle_noncurrent_version_expiration_days != null ? [var.hybrid_recording_lifecycle_noncurrent_version_expiration_days] : []
      content { noncurrent_days = noncurrent_version_expiration.value }
    }
  }
  depends_on = [aws_s3_bucket_versioning.hybrid_recording]
}

resource "aws_s3_bucket" "node_group" {
  for_each = var.managed_node_group_s3_buckets
  bucket   = each.value.bucket_name
  tags     = merge(var.common_tags, { Name = each.value.bucket_name })
}

resource "aws_s3_bucket_public_access_block" "node_group" {
  for_each                = var.managed_node_group_s3_buckets
  bucket                  = aws_s3_bucket.node_group[each.key].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "node_group" {
  for_each = var.managed_node_group_s3_buckets
  bucket   = aws_s3_bucket.node_group[each.key].id
  rule {
    bucket_key_enabled = each.value.kms_key_arn != null
    apply_server_side_encryption_by_default {
      kms_master_key_id = each.value.kms_key_arn
      sse_algorithm     = each.value.kms_key_arn != null ? "aws:kms" : "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "node_group" {
  for_each = { for access_key, access in var.managed_node_group_s3_buckets : access_key => access if access.versioning_enabled }
  bucket   = aws_s3_bucket.node_group[each.key].id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_lifecycle_configuration" "node_group" {
  for_each = var.node_group_s3_lifecycle_buckets
  bucket   = aws_s3_bucket.node_group[each.key].id
  rule {
    id     = "zoom-node-managed-retention"
    status = "Enabled"
    filter {}
    dynamic "expiration" {
      for_each = each.value.lifecycle_expiration_days != null ? [each.value.lifecycle_expiration_days] : []
      content { days = expiration.value }
    }
    dynamic "noncurrent_version_expiration" {
      for_each = each.value.lifecycle_noncurrent_version_expiration_days != null ? [each.value.lifecycle_noncurrent_version_expiration_days] : []
      content { noncurrent_days = noncurrent_version_expiration.value }
    }
  }
  depends_on = [aws_s3_bucket_versioning.node_group]
}

resource "aws_iam_role" "zoom_node" {
  for_each             = var.iam_profile_configs
  name_prefix          = var.environment_name == "" ? "${each.value.prefix}-zoom-node-" : "${var.environment_name}-${each.value.prefix}-zoom-node-"
  path                 = var.iam_path
  permissions_boundary = var.permissions_boundary
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Principal = { Service = "ec2.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
  tags = merge(var.common_tags, {
    Name     = var.environment_name == "" ? "${each.value.prefix}-zoom-node-role" : "${var.environment_name}-${each.value.prefix}-zoom-node-role"
    Workload = each.value.label
  })
}

resource "aws_iam_instance_profile" "zoom_node" {
  for_each    = var.iam_profile_configs
  name_prefix = var.environment_name == "" ? "${each.value.prefix}-zoom-node-" : "${var.environment_name}-${each.value.prefix}-zoom-node-"
  path        = var.iam_path
  role        = aws_iam_role.zoom_node[each.key].name
  tags = merge(var.common_tags, {
    Name     = var.environment_name == "" ? "${each.value.prefix}-zoom-node-profile" : "${var.environment_name}-${each.value.prefix}-zoom-node-profile"
    Workload = each.value.label
  })
}

resource "aws_iam_role_policy" "hybrid_recording_s3" {
  for_each = var.hybrid_recording_enabled ? { HybridRecording = true } : {}
  name     = "HybridRecordingS3FullAccess"
  role     = aws_iam_role.zoom_node[each.key].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat([{
      Sid      = "FullAccessToBucket", Effect = "Allow", Action = var.hybrid_recording_actions
      Resource = ["arn:aws:s3:::${var.hybrid_recording_bucket_name}", "arn:aws:s3:::${var.hybrid_recording_bucket_name}/*"]
      }], var.hybrid_recording_kms_key_arn != null ? [{
      Sid      = "UseHybridRecordingKmsKey", Effect = "Allow"
      Action   = ["kms:Decrypt", "kms:Encrypt", "kms:GenerateDataKey", "kms:DescribeKey"]
      Resource = var.hybrid_recording_kms_key_arn
    }] : [])
  })
}

resource "aws_iam_role_policy" "node_group_s3" {
  for_each = var.node_group_s3_policy_records
  name     = "${each.value.access_key}-s3-access"
  role     = aws_iam_role.zoom_node[each.value.profile_key].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat([{
      Sid      = "BucketScopedAccess", Effect = "Allow", Action = each.value.actions
      Resource = ["arn:aws:s3:::${each.value.bucket_name}", "arn:aws:s3:::${each.value.bucket_name}/*"]
      }], each.value.kms_key_arn != null ? [{
      Sid      = "UseBucketKmsKey", Effect = "Allow"
      Action   = ["kms:Decrypt", "kms:Encrypt", "kms:GenerateDataKey", "kms:DescribeKey"]
      Resource = each.value.kms_key_arn
    }] : [])
  })
}
