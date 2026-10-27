locals {
  create_new_network = var.network_mode == "create_new"

  explicit_public_subnet_indices  = [for _, group in var.node_groups : group.subnet_index if group.subnet_tier == "public" && group.subnet_index != null]
  explicit_private_subnet_indices = [for _, group in var.node_groups : group.subnet_index if group.subnet_tier == "private" && group.subnet_index != null]
  requires_public_subnets         = length(local.enabled_workloads) > 0 || anytrue([for _, group in var.node_groups : group.subnet_tier == "public"])
  requires_private_subnets        = anytrue([for _, group in var.node_groups : group.subnet_tier == "private"])
  requested_public_subnet_count = max(concat(
    [local.subnet_count, length(var.aws.public_subnet_cidrs)],
    [for subnet_index in local.explicit_public_subnet_indices : subnet_index + 1]
  )...)
  requested_private_subnet_count = max(concat(
    [local.subnet_count, length(var.aws.private_subnet_cidrs)],
    [for subnet_index in local.explicit_private_subnet_indices : subnet_index + 1]
  )...)
  public_subnet_count  = local.create_new_network && local.requires_public_subnets ? local.requested_public_subnet_count : 0
  private_subnet_count = local.create_new_network && local.requires_private_subnets ? local.requested_private_subnet_count : 0
  managed_subnet_count = max(local.public_subnet_count, local.private_subnet_count)
  az_candidates = length(var.aws.availability_zones) > 0 ? concat(
    var.aws.availability_zones,
    [for az in data.aws_availability_zones.available.names : az if !contains(var.aws.availability_zones, az)]
  ) : data.aws_availability_zones.available.names
  az_names = slice(local.az_candidates, 0, local.managed_subnet_count)

  configured_public_subnet_cidrs = [
    for subnet_index in range(local.public_subnet_count) :
    length(var.aws.public_subnet_cidrs) > subnet_index ? var.aws.public_subnet_cidrs[subnet_index] : (
      length(var.aws.subnet_cidrs) > subnet_index ? var.aws.subnet_cidrs[subnet_index] : cidrsubnet(var.aws.vpc_cidr, var.aws.subnet_newbits, subnet_index)
    )
  ]
  configured_private_subnet_cidrs = [
    for subnet_index in range(local.private_subnet_count) :
    length(var.aws.private_subnet_cidrs) > subnet_index ? var.aws.private_subnet_cidrs[subnet_index] : cidrsubnet(var.aws.vpc_cidr, var.aws.subnet_newbits, local.subnet_count + subnet_index)
  ]

  effective_vpc_id               = module.network.vpc_id
  effective_vpc_cidr             = module.network.vpc_cidr
  effective_public_subnet_ids    = module.network.public_subnet_ids
  effective_public_subnet_cidrs  = module.network.public_subnet_cidrs
  effective_private_subnet_ids   = module.network.private_subnet_ids
  effective_private_subnet_cidrs = module.network.private_subnet_cidrs
  effective_subnet_ids           = module.network.public_subnet_ids
  effective_dns_servers          = module.network.dns_servers
}
