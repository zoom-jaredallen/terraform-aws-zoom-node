output "instance_ids" {
  description = "EC2 instance IDs by Zoom Node hostname."
  value       = module.zoom_node.instance_ids
}

output "private_ips" {
  description = "Configured primary private IPs by Zoom Node hostname."
  value       = module.zoom_node.node_private_ips
}

output "capacity_preflight_requests" {
  description = "Nonsensitive EC2 capacity requests for the planned nodes."
  value       = module.zoom_node.capacity_preflight_requests
}
