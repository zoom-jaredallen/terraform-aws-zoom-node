output "node_instance_ids" {
  description = "EC2 instance IDs keyed by stable node key."
  value       = module.zoom_node.instance_ids
}

output "capacity_preflight_requests" {
  description = "Nonsensitive EC2 capacity requests for the planned nodes."
  value       = module.zoom_node.capacity_preflight_requests
}
