output "security_group_ids" { value = { for key, group in aws_security_group.zoom_node : key => group.id } }
output "instance_ids" { value = { for key, instance in aws_instance.zoom_node : key => instance.id } }
output "node_public_ips" {
  value = {
    for node_key, node in var.node_records : node_key => [
      for eip_key, eip in aws_eip.zoom_node : eip.public_ip if var.node_eip_records[eip_key].node_key == node_key
    ]
  }
}
output "instances" {
  sensitive = true
  value = {
    for key, instance in aws_instance.zoom_node : key => {
      ami                                  = instance.ami
      instance_type                        = instance.instance_type
      user_data_base64                     = instance.user_data_base64
      metadata_http_tokens                 = one(instance.metadata_options).http_tokens
      metadata_http_put_response_hop_limit = one(instance.metadata_options).http_put_response_hop_limit
      market_type                          = try(one(instance.instance_market_options).market_type, null)
      root_volume_size                     = one(instance.root_block_device).volume_size
      root_volume_kms_key_id               = one(instance.root_block_device).kms_key_id
    }
  }
}
output "network_interfaces" {
  value = { for key, eni in aws_network_interface.zoom_node : key => {
    subnet_id = eni.subnet_id, private_ips = eni.private_ips, source_dest_check = eni.source_dest_check
  } }
}
output "log_groups" { value = { for key, group in aws_cloudwatch_log_group.zoom_node : key => { retention_in_days = group.retention_in_days, kms_key_id = group.kms_key_id } } }
output "eip_count" { value = length(aws_eip.zoom_node) }
output "ingress_rule_count" { value = length(aws_vpc_security_group_ingress_rule.zoom_node) }
output "egress_rule_count" { value = length(aws_vpc_security_group_egress_rule.zoom_node) }
