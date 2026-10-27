variable "hybrid_recording_enabled" { type = bool }
variable "hybrid_recording_bucket_mode" { type = string }
variable "hybrid_recording_bucket_name" { type = string }
variable "hybrid_recording_kms_key_arn" {
  type    = string
  default = null
}
variable "hybrid_recording_versioning_enabled" { type = bool }
variable "hybrid_recording_lifecycle_expiration_days" {
  type    = number
  default = null
}
variable "hybrid_recording_lifecycle_noncurrent_version_expiration_days" {
  type    = number
  default = null
}
variable "hybrid_recording_actions" { type = list(string) }
variable "managed_node_group_s3_buckets" {
  type = map(object({
    bucket_name                                  = string
    versioning_enabled                           = bool
    lifecycle_expiration_days                    = number
    lifecycle_noncurrent_version_expiration_days = number
    kms_key_arn                                  = string
  }))
}
variable "node_group_s3_lifecycle_buckets" {
  type = map(object({
    lifecycle_expiration_days                    = number
    lifecycle_noncurrent_version_expiration_days = number
  }))
}
variable "node_group_s3_policy_records" {
  type = map(object({
    access_key  = string
    profile_key = string
    bucket_name = string
    actions     = set(string)
    kms_key_arn = string
  }))
}
variable "iam_profile_configs" {
  type = map(object({ prefix = string, label = string }))
}
variable "iam_path" { type = string }
variable "permissions_boundary" {
  type    = string
  default = null
}
variable "environment_name" { type = string }
variable "common_tags" { type = map(string) }
