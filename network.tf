locals {
  create_new_network = var.network_mode == "create_new"

  explicit_public_subnet_indices = [
    for _, group in var.node_groups : group.subnet_index
    if group.subnet_tier == "public" && group.subnet_index != null
  ]
  explicit_private_subnet_indices = [
    for _, group in var.node_groups : group.subnet_index
    if group.subnet_tier == "private" && group.subnet_index != null
  ]

  requires_public_subnets  = length(local.enabled_workloads) > 0 || anytrue([for _, group in var.node_groups : group.subnet_tier == "public"])
  requires_private_subnets = anytrue([for _, group in var.node_groups : group.subnet_tier == "private"])
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
}

resource "aws_vpc" "this" {
  count                = local.create_new_network ? 1 : 0
  cidr_block           = var.aws.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(local.common_tags, {
    Name = var.environment_name == "" ? "zoom-node-vpc" : "${var.environment_name}-zoom-node-vpc"
  })
}

resource "aws_internet_gateway" "this" {
  count  = local.create_new_network && var.deployment_mode == "public_cloud" ? 1 : 0
  vpc_id = aws_vpc.this[0].id

  tags = merge(local.common_tags, {
    Name = var.environment_name == "" ? "zoom-node-igw" : "${var.environment_name}-zoom-node-igw"
  })
}

resource "aws_subnet" "zoom_node" {
  count                   = local.public_subnet_count
  vpc_id                  = aws_vpc.this[0].id
  cidr_block              = local.configured_public_subnet_cidrs[count.index]
  availability_zone       = local.az_names[count.index]
  map_public_ip_on_launch = var.aws.enable_public_ipv4_on_boot

  tags = merge(local.common_tags, {
    Name = var.environment_name == "" ? "zoom-node-subnet-${count.index + 1}" : "${var.environment_name}-zoom-node-subnet-${count.index + 1}"
  })
}

resource "aws_subnet" "private" {
  count                   = local.private_subnet_count
  vpc_id                  = aws_vpc.this[0].id
  cidr_block              = local.configured_private_subnet_cidrs[count.index]
  availability_zone       = local.az_names[count.index]
  map_public_ip_on_launch = false

  tags = merge(local.common_tags, {
    Name = var.environment_name == "" ? "zoom-node-private-subnet-${count.index + 1}" : "${var.environment_name}-zoom-node-private-subnet-${count.index + 1}"
  })
}

resource "aws_route_table" "public" {
  count  = local.create_new_network && var.deployment_mode == "public_cloud" ? 1 : 0
  vpc_id = aws_vpc.this[0].id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this[0].id
  }

  tags = merge(local.common_tags, {
    Name = var.environment_name == "" ? "zoom-node-public-rt" : "${var.environment_name}-zoom-node-public-rt"
  })
}

resource "aws_route_table_association" "public" {
  count          = local.create_new_network && var.deployment_mode == "public_cloud" ? local.public_subnet_count : 0
  subnet_id      = aws_subnet.zoom_node[count.index].id
  route_table_id = aws_route_table.public[0].id
}

resource "aws_eip" "nat" {
  count  = local.create_new_network && var.aws.create_nat_gateway ? 1 : 0
  domain = "vpc"

  tags = merge(local.common_tags, {
    Name = var.environment_name == "" ? "zoom-node-nat-eip" : "${var.environment_name}-zoom-node-nat-eip"
  })

  depends_on = [aws_internet_gateway.this]
}

resource "aws_nat_gateway" "this" {
  count         = local.create_new_network && var.aws.create_nat_gateway ? 1 : 0
  allocation_id = aws_eip.nat[0].id
  subnet_id     = aws_subnet.zoom_node[0].id

  tags = merge(local.common_tags, {
    Name = var.environment_name == "" ? "zoom-node-nat" : "${var.environment_name}-zoom-node-nat"
  })

  depends_on = [aws_route_table_association.public]
}

resource "aws_route_table" "private" {
  count  = local.create_new_network && local.requires_private_subnets ? 1 : 0
  vpc_id = aws_vpc.this[0].id

  dynamic "route" {
    for_each = var.aws.create_nat_gateway ? [1] : []
    content {
      cidr_block     = "0.0.0.0/0"
      nat_gateway_id = aws_nat_gateway.this[0].id
    }
  }

  tags = merge(local.common_tags, {
    Name = var.environment_name == "" ? "zoom-node-private-rt" : "${var.environment_name}-zoom-node-private-rt"
  })
}

resource "aws_route_table_association" "private" {
  count          = local.private_subnet_count
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[0].id
}

data "aws_vpc" "existing" {
  count = local.create_new_network ? 0 : 1
  id    = var.aws.existing_vpc_id
}

data "aws_subnet" "existing" {
  for_each = local.create_new_network ? toset([]) : toset(var.aws.existing_subnet_ids)
  id       = each.value
}

locals {
  effective_vpc_id               = local.create_new_network ? aws_vpc.this[0].id : var.aws.existing_vpc_id
  effective_vpc_cidr             = local.create_new_network ? var.aws.vpc_cidr : data.aws_vpc.existing[0].cidr_block
  effective_public_subnet_ids    = local.create_new_network ? aws_subnet.zoom_node[*].id : var.aws.existing_subnet_ids
  effective_public_subnet_cidrs  = local.create_new_network ? aws_subnet.zoom_node[*].cidr_block : [for subnet_id in var.aws.existing_subnet_ids : data.aws_subnet.existing[subnet_id].cidr_block]
  effective_private_subnet_ids   = local.create_new_network ? aws_subnet.private[*].id : []
  effective_private_subnet_cidrs = local.create_new_network ? aws_subnet.private[*].cidr_block : []
  effective_subnet_ids           = local.effective_public_subnet_ids
  effective_dns_servers          = length(var.aws.dns_servers) > 0 ? var.aws.dns_servers : [cidrhost(local.effective_vpc_cidr, 2)]
}
