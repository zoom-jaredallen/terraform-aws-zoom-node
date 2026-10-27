output "node_fqdns" {
  description = "Zoom Node fully qualified domain names keyed by stable node key."
  value       = module.zoom_node.node_fqdns
}

output "node_private_ips" {
  description = "Private IPv4 addresses keyed by stable node key."
  value       = module.zoom_node.node_private_ips
}

output "node_public_ips" {
  description = "Elastic IPv4 addresses keyed by stable node key."
  value       = module.zoom_node.node_public_ips
}

output "generated_node_password" {
  description = "Generated Zoom Node administrator password."
  value       = module.zoom_node.generated_node_password
  sensitive   = true
}
