resource "aws_security_group" "zoom_node" {
  for_each    = var.security_group_configs
  name_prefix = var.environment_name == "" ? "${each.value.prefix}-zoom-node-" : "${var.environment_name}-${each.value.prefix}-zoom-node-"
  description = each.value.advanced ? "Zoom Node ${each.key} security profile" : "Zoom Node ${each.key} security group"
  vpc_id      = var.vpc_id
  tags = merge(
    var.common_tags,
    { Name = var.environment_name == "" ? "${each.value.prefix}-zoom-node-sg" : "${var.environment_name}-${each.value.prefix}-zoom-node-sg" },
    each.value.advanced ? { Profile = each.key } : { Workload = each.key }
  )
}

resource "aws_vpc_security_group_ingress_rule" "zoom_node" {
  for_each          = var.ingress_rule_records
  security_group_id = aws_security_group.zoom_node[each.value.security_group_key].id
  description       = each.value.description
  ip_protocol       = each.value.protocol
  from_port         = each.value.protocol == "-1" ? null : each.value.from_port
  to_port           = each.value.protocol == "-1" ? null : each.value.to_port
  cidr_ipv4         = each.value.cidr
  tags              = merge(var.common_tags, { Name = each.key })
}

resource "aws_vpc_security_group_egress_rule" "zoom_node" {
  for_each          = var.egress_rule_records
  security_group_id = aws_security_group.zoom_node[each.value.security_group_key].id
  description       = each.value.description
  ip_protocol       = each.value.protocol
  from_port         = each.value.protocol == "-1" ? null : each.value.from_port
  to_port           = each.value.protocol == "-1" ? null : each.value.to_port
  cidr_ipv4         = each.value.cidr
  tags              = merge(var.common_tags, { Name = each.key })
}

resource "aws_network_interface" "zoom_node" {
  for_each          = var.node_records
  subnet_id         = var.node_subnet_ids[each.key]
  security_groups   = [aws_security_group.zoom_node[each.value.security_profile].id]
  private_ips       = var.node_private_ips[each.key]
  source_dest_check = each.value.source_dest_check
  tags = merge(var.common_tags, {
    Name          = "${each.value.node_name}-eni"
    Workload      = each.value.workload_type
    ZoomNodeIndex = format("%02d", each.value.node_number)
    ZoomNodeName  = each.value.node_name
  })
  lifecycle { ignore_changes = [private_ips] }
  depends_on = [aws_vpc_security_group_ingress_rule.zoom_node, aws_vpc_security_group_egress_rule.zoom_node]
}

resource "aws_cloudwatch_log_group" "zoom_node" {
  for_each          = var.node_records
  name              = "/zoom-node/${each.value.node_name}"
  retention_in_days = var.cloudwatch_log_retention_days
  kms_key_id        = var.cloudwatch_log_kms_key_id
  tags = merge(var.common_tags, {
    Name          = "${each.value.node_name}-logs"
    Workload      = each.value.workload_type
    ZoomNodeIndex = format("%02d", each.value.node_number)
    ZoomNodeName  = each.value.node_name
  })
}

resource "aws_instance" "zoom_node" {
  for_each                    = var.node_records
  ami                         = each.value.image_id
  instance_type               = each.value.instance_type
  key_name                    = var.key_name
  iam_instance_profile        = var.iam_instance_profile_names[each.value.iam_profile_key]
  user_data_base64            = base64encode(var.node_user_data[each.key])
  user_data_replace_on_change = false
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = each.value.metadata_http_put_response_hop_limit
  }
  dynamic "instance_market_options" {
    for_each = each.value.purchase_option == "spot" ? [1] : []
    content {
      market_type = "spot"
      spot_options { instance_interruption_behavior = "terminate" }
    }
  }
  primary_network_interface { network_interface_id = aws_network_interface.zoom_node[each.key].id }
  root_block_device {
    volume_size = each.value.root_volume_gb
    volume_type = "gp3"
    encrypted   = var.root_volume_encrypted
    kms_key_id  = var.root_volume_kms_key_id
  }
  tags = merge(var.common_tags, var.instance_tags, {
    Name          = each.value.fqdn
    Workload      = each.value.workload_type
    ZoomNodeIndex = format("%02d", each.value.node_number)
    ZoomNodeName  = each.value.node_name
  })
  lifecycle { ignore_changes = [source_dest_check, user_data_base64] }
  depends_on = [aws_cloudwatch_log_group.zoom_node]
}

resource "aws_eip" "zoom_node" {
  for_each = var.node_eip_records
  domain   = "vpc"
  tags     = merge(var.common_tags, { Name = "${each.value.node_name}-eip-${each.value.eip_index}", Workload = each.value.workload })
}

resource "aws_eip_association" "zoom_node" {
  for_each             = var.node_eip_records
  allocation_id        = aws_eip.zoom_node[each.key].id
  network_interface_id = aws_network_interface.zoom_node[each.value.node_key].id
  private_ip_address   = each.value.private_ip
}
