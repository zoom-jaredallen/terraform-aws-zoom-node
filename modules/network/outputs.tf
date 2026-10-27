output "vpc_id" { value = var.create_new_network ? aws_vpc.this[0].id : var.existing_vpc_id }
output "vpc_cidr" { value = var.create_new_network ? var.vpc_cidr : data.aws_vpc.existing[0].cidr_block }
output "public_subnet_ids" { value = var.create_new_network ? aws_subnet.zoom_node[*].id : var.existing_subnet_ids }
output "public_subnet_cidrs" { value = var.create_new_network ? aws_subnet.zoom_node[*].cidr_block : [for subnet_id in var.existing_subnet_ids : data.aws_subnet.existing[subnet_id].cidr_block] }
output "private_subnet_ids" { value = var.create_new_network ? aws_subnet.private[*].id : [] }
output "private_subnet_cidrs" { value = var.create_new_network ? aws_subnet.private[*].cidr_block : [] }
output "dns_servers" { value = length(var.dns_servers) > 0 ? var.dns_servers : [cidrhost(var.create_new_network ? var.vpc_cidr : data.aws_vpc.existing[0].cidr_block, 2)] }
output "nat_gateway_id" { value = try(aws_nat_gateway.this[0].id, null) }
output "nat_gateway_public_ip" { value = try(aws_eip.nat[0].public_ip, null) }
output "test_contract" {
  value = {
    vpc_count                  = length(aws_vpc.this)
    public_subnets             = [for subnet in aws_subnet.zoom_node : { id = subnet.id, availability_zone = subnet.availability_zone }]
    private_subnet_count       = length(aws_subnet.private)
    private_default_route_cidr = var.create_nat_gateway ? "0.0.0.0/0" : null
    nat_gateway_count          = length(aws_nat_gateway.this)
    nat_eip_count              = length(aws_eip.nat)
  }
}
