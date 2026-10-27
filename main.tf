module "network" {
  source = "./modules/network"

  create_new_network         = local.create_new_network
  deployment_mode            = var.deployment_mode
  vpc_cidr                   = var.aws.vpc_cidr
  public_subnet_count        = local.public_subnet_count
  private_subnet_count       = local.private_subnet_count
  requires_private_subnets   = local.requires_private_subnets
  public_subnet_cidrs        = local.configured_public_subnet_cidrs
  private_subnet_cidrs       = local.configured_private_subnet_cidrs
  availability_zones         = local.az_names
  enable_public_ipv4_on_boot = var.aws.enable_public_ipv4_on_boot
  create_nat_gateway         = var.aws.create_nat_gateway
  existing_vpc_id            = var.aws.existing_vpc_id
  existing_subnet_ids        = var.aws.existing_subnet_ids
  dns_servers                = var.aws.dns_servers
  environment_name           = var.environment_name
  common_tags                = local.common_tags
}

module "storage_access" {
  source = "./modules/storage-access"

  hybrid_recording_enabled                                      = local.dedicated_hybrid_recording_storage_active
  hybrid_recording_bucket_mode                                  = var.hybrid_recording_s3_bucket_mode
  hybrid_recording_bucket_name                                  = var.hybrid_recording_s3_bucket_name
  hybrid_recording_kms_key_arn                                  = var.aws.hybrid_recording_s3_kms_key_arn
  hybrid_recording_versioning_enabled                           = var.aws.hybrid_recording_s3_versioning_enabled
  hybrid_recording_lifecycle_expiration_days                    = var.aws.hybrid_recording_s3_lifecycle_expiration_days
  hybrid_recording_lifecycle_noncurrent_version_expiration_days = var.aws.hybrid_recording_s3_lifecycle_noncurrent_version_expiration_days
  hybrid_recording_actions                                      = var.aws.hybrid_recording_s3_actions
  managed_node_group_s3_buckets                                 = local.managed_node_group_s3_buckets
  node_group_s3_lifecycle_buckets                               = local.node_group_s3_lifecycle_buckets
  node_group_s3_policy_records                                  = local.node_group_s3_policy_records
  iam_profile_configs                                           = local.iam_profile_configs
  iam_path                                                      = var.aws.iam_path
  permissions_boundary                                          = var.aws.permissions_boundary
  environment_name                                              = var.environment_name
  common_tags                                                   = local.common_tags
}

module "node" {
  source = "./modules/node"

  node_records                  = local.node_records
  node_subnet_ids               = local.node_subnet_ids
  node_private_ips              = local.node_private_ips
  node_user_data                = local.node_user_data
  node_eip_records              = local.node_eip_records
  security_group_configs        = local.security_group_configs
  ingress_rule_records          = local.ingress_rule_records
  egress_rule_records           = local.egress_rule_records
  iam_instance_profile_names    = module.storage_access.iam_instance_profile_names
  vpc_id                        = local.effective_vpc_id
  key_name                      = var.aws.key_name
  root_volume_encrypted         = var.aws.root_volume_encrypted
  root_volume_kms_key_id        = var.aws.root_volume_kms_key_id
  cloudwatch_log_retention_days = var.aws.cloudwatch_log_retention_days
  cloudwatch_log_kms_key_id     = var.aws.cloudwatch_log_kms_key_id
  instance_tags                 = var.aws.instance_tags
  environment_name              = var.environment_name
  common_tags                   = local.common_tags

  depends_on = [module.network, module.storage_access]
}
