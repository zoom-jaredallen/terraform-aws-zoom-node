output "instance_id" {
  description = "EC2 instance ID for the original AI Services node."
  value       = module.zoom_node.instance_ids[var.node_name]
}

output "private_ip" {
  description = "Private IP assigned to the original AI Services node."
  value       = module.zoom_node.node_private_ips[var.node_name][0]
}

output "instance_ids" {
  description = "EC2 instance IDs keyed by AI Services node hostname."
  value       = module.zoom_node.instance_ids
}

output "private_ips" {
  description = "Private IPs keyed by AI Services node hostname."
  value       = { for node_name, private_ips in module.zoom_node.node_private_ips : node_name => private_ips[0] }
}

output "security_group_id" {
  description = "Security group ID assigned to the AI Services nodes."
  value       = aws_security_group.ai_services.id
}

output "capacity_preflight_requests" {
  description = "Nonsensitive EC2 capacity requests for the planned nodes."
  value       = module.zoom_node.capacity_preflight_requests
}
