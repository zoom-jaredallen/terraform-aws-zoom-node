output "instance_ids" {
  description = "EC2 instance IDs by Zoom Node hostname."
  value       = module.zoom_node.instance_ids
}

output "private_ips" {
  description = "Private IPs by Zoom Node hostname."
  value       = { for node_name, private_ips in module.zoom_node.node_private_ips : node_name => private_ips[0] }
}

output "public_ips" {
  description = "Elastic public IPs by Zoom Node hostname."
  value       = { for node_name, public_ips in module.zoom_node.node_public_ips : node_name => public_ips[0] }
}

output "vpc_id" {
  description = "VPC adopted by the Sydney public Zoom Node deployment."
  value       = module.zoom_node.vpc_id
}

output "capacity_preflight_requests" {
  description = "Nonsensitive EC2 capacity requests for the planned nodes."
  value       = module.zoom_node.capacity_preflight_requests
}
