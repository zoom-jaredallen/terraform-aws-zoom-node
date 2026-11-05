output "instance_ids" {
  value = module.zoom_node.instance_ids
}

output "node_fqdns" {
  value = module.zoom_node.node_fqdns
}

output "node_private_ips" {
  value = module.zoom_node.node_private_ips
}

output "node_public_ips" {
  value = module.zoom_node.node_public_ips
}

output "node_roles" {
  value = module.zoom_node.node_roles
}

output "node_purchase_options" {
  value = module.zoom_node.node_purchase_options
}

output "nat_gateway_public_ip" {
  value = module.zoom_node.nat_gateway_public_ip
}

output "iam_instance_profile_names" {
  value = module.zoom_node.iam_instance_profile_names
}

output "security_group_ids" {
  value = module.zoom_node.security_group_ids
}

output "s3_bucket_names" {
  value = module.zoom_node.s3_bucket_names
}

output "generated_node_password" {
  value     = module.zoom_node.generated_node_password
  sensitive = true
}

output "capacity_preflight_requests" {
  description = "Nonsensitive EC2 capacity requests for the planned nodes."
  value       = module.zoom_node.capacity_preflight_requests
}

output "control_plane_virtual_ip" {
  description = "Configured Kubernetes control-plane virtual IP and owning ENI."
  value       = module.zoom_node.control_plane_virtual_ip
}
