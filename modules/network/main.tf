resource "aws_vpc" "this" {
  count                = var.create_new_network ? 1 : 0
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags                 = merge(var.common_tags, { Name = var.environment_name == "" ? "zoom-node-vpc" : "${var.environment_name}-zoom-node-vpc" })
}

resource "aws_internet_gateway" "this" {
  count  = var.create_new_network && var.deployment_mode == "public_cloud" ? 1 : 0
  vpc_id = aws_vpc.this[0].id
  tags   = merge(var.common_tags, { Name = var.environment_name == "" ? "zoom-node-igw" : "${var.environment_name}-zoom-node-igw" })
}

resource "aws_subnet" "zoom_node" {
  count                   = var.public_subnet_count
  vpc_id                  = aws_vpc.this[0].id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = var.enable_public_ipv4_on_boot
  tags                    = merge(var.common_tags, { Name = var.environment_name == "" ? "zoom-node-subnet-${count.index + 1}" : "${var.environment_name}-zoom-node-subnet-${count.index + 1}" })
}

resource "aws_subnet" "private" {
  count                   = var.private_subnet_count
  vpc_id                  = aws_vpc.this[0].id
  cidr_block              = var.private_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = false
  tags                    = merge(var.common_tags, { Name = var.environment_name == "" ? "zoom-node-private-subnet-${count.index + 1}" : "${var.environment_name}-zoom-node-private-subnet-${count.index + 1}" })
}

resource "aws_route_table" "public" {
  count  = var.create_new_network && var.deployment_mode == "public_cloud" ? 1 : 0
  vpc_id = aws_vpc.this[0].id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this[0].id
  }
  tags = merge(var.common_tags, { Name = var.environment_name == "" ? "zoom-node-public-rt" : "${var.environment_name}-zoom-node-public-rt" })
}

resource "aws_route_table_association" "public" {
  count          = var.create_new_network && var.deployment_mode == "public_cloud" ? var.public_subnet_count : 0
  subnet_id      = aws_subnet.zoom_node[count.index].id
  route_table_id = aws_route_table.public[0].id
}

resource "aws_eip" "nat" {
  count      = var.create_new_network && var.create_nat_gateway ? 1 : 0
  domain     = "vpc"
  tags       = merge(var.common_tags, { Name = var.environment_name == "" ? "zoom-node-nat-eip" : "${var.environment_name}-zoom-node-nat-eip" })
  depends_on = [aws_internet_gateway.this]
}

resource "aws_nat_gateway" "this" {
  count         = var.create_new_network && var.create_nat_gateway ? 1 : 0
  allocation_id = aws_eip.nat[0].id
  subnet_id     = aws_subnet.zoom_node[0].id
  tags          = merge(var.common_tags, { Name = var.environment_name == "" ? "zoom-node-nat" : "${var.environment_name}-zoom-node-nat" })
  depends_on    = [aws_route_table_association.public]
}

resource "aws_route_table" "private" {
  count  = var.create_new_network && var.requires_private_subnets ? 1 : 0
  vpc_id = aws_vpc.this[0].id
  dynamic "route" {
    for_each = var.create_nat_gateway ? [1] : []
    content {
      cidr_block     = "0.0.0.0/0"
      nat_gateway_id = aws_nat_gateway.this[0].id
    }
  }
  tags = merge(var.common_tags, { Name = var.environment_name == "" ? "zoom-node-private-rt" : "${var.environment_name}-zoom-node-private-rt" })
}

resource "aws_route_table_association" "private" {
  count          = var.private_subnet_count
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[0].id
}

data "aws_vpc" "existing" {
  count = var.create_new_network ? 0 : 1
  id    = var.existing_vpc_id
}

data "aws_subnet" "existing" {
  for_each = var.create_new_network ? toset([]) : toset(var.existing_subnet_ids)
  id       = each.value
}
