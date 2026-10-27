locals {
  node_subnet_ids = {
    for node_key, node in local.node_records : node_key => (
      node.subnet_tier == "private" ? local.effective_private_subnet_ids[node.subnet_index] : local.effective_public_subnet_ids[node.subnet_index]
    )
  }

  node_subnet_cidrs = {
    for node_key, node in local.node_records : node_key => (
      node.subnet_tier == "private" ? local.effective_private_subnet_cidrs[node.subnet_index] : local.effective_public_subnet_cidrs[node.subnet_index]
    )
  }

  node_subnet_prefix_lengths = {
    for node_key, cidr in local.node_subnet_cidrs : node_key => tonumber(split("/", cidr)[1])
  }

  node_private_ips = {
    for node_key, node in local.node_records : node_key => [
      for ip_index in range(node.private_ips_per_eni) :
      cidrhost(local.node_subnet_cidrs[node_key], node.node_start_offset + (node.node_index * max(10, node.private_ips_per_eni)) + ip_index)
    ]
  }

  node_user_data = {
    for node_key, node in local.node_records : node_key => templatefile("${path.module}/templates/cloud-init.tftpl", {
      hostname               = node.fqdn
      password               = local.effective_node_password
      registration_code      = var.registration_code
      network_interface_name = local.node_network_interface_names[node_key]
      addresses              = [for ip in local.node_private_ips[node_key] : "${ip}/${local.node_subnet_prefix_lengths[node_key]}"]
      gateway                = cidrhost(local.node_subnet_cidrs[node_key], 1)
      dns_servers            = local.effective_dns_servers
    })
  }

  node_eip_record_list = flatten([
    for node_key, node in local.node_records : [
      for eip_index in range(node.elastic_ips_per_node) : {
        key        = "${node_key}-eip-${eip_index}"
        node_key   = node_key
        eip_index  = eip_index
        private_ip = local.node_private_ips[node_key][eip_index]
        node_name  = node.node_name
        workload   = node.workload_type
      }
    ]
  ])

  node_eip_records = {
    for record in local.node_eip_record_list : record.key => record
  }
}

resource "random_password" "node" {
  count = var.generate_node_password ? 1 : 0

  length           = 16
  special          = true
  min_upper        = 1
  min_lower        = 1
  min_numeric      = 1
  min_special      = 1
  override_special = "!.@%#*_%~?"
}

resource "aws_network_interface" "zoom_node" {
  for_each          = local.node_records
  subnet_id         = local.node_subnet_ids[each.key]
  security_groups   = [aws_security_group.zoom_node[each.value.security_profile].id]
  private_ips       = local.node_private_ips[each.key]
  source_dest_check = each.value.source_dest_check

  tags = merge(local.common_tags, {
    Name          = "${each.value.node_name}-eni"
    Workload      = each.value.workload_type
    ZoomNodeIndex = format("%02d", each.value.node_number)
    ZoomNodeName  = each.value.node_name
  })

  lifecycle {
    ignore_changes = [private_ips]
  }

  depends_on = [
    aws_vpc_security_group_ingress_rule.zoom_node,
    aws_vpc_security_group_egress_rule.zoom_node,
  ]
}

resource "aws_cloudwatch_log_group" "zoom_node" {
  for_each          = local.node_records
  name              = "/zoom-node/${each.value.node_name}"
  retention_in_days = var.aws.cloudwatch_log_retention_days
  kms_key_id        = var.aws.cloudwatch_log_kms_key_id

  tags = merge(local.common_tags, {
    Name          = "${each.value.node_name}-logs"
    Workload      = each.value.workload_type
    ZoomNodeIndex = format("%02d", each.value.node_number)
    ZoomNodeName  = each.value.node_name
  })
}

resource "aws_instance" "zoom_node" {
  for_each                    = local.node_records
  ami                         = each.value.image_id
  instance_type               = each.value.instance_type
  key_name                    = var.aws.key_name
  iam_instance_profile        = aws_iam_instance_profile.zoom_node[each.value.iam_profile_key].name
  user_data_base64            = base64encode(local.node_user_data[each.key])
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

      spot_options {
        instance_interruption_behavior = "terminate"
      }
    }
  }

  primary_network_interface {
    network_interface_id = aws_network_interface.zoom_node[each.key].id
  }

  root_block_device {
    volume_size = each.value.root_volume_gb
    volume_type = "gp3"
    encrypted   = var.aws.root_volume_encrypted
    kms_key_id  = var.aws.root_volume_kms_key_id
  }

  tags = merge(
    local.common_tags,
    var.aws.instance_tags,
    {
      Name          = each.value.fqdn
      Workload      = each.value.workload_type
      ZoomNodeIndex = format("%02d", each.value.node_number)
      ZoomNodeName  = each.value.node_name
    }
  )

  lifecycle {
    ignore_changes = [
      source_dest_check,
      user_data_base64,
    ]
  }

  depends_on = [
    aws_cloudwatch_log_group.zoom_node,
    aws_route_table_association.private
  ]
}

resource "aws_eip" "zoom_node" {
  for_each = local.node_eip_records
  domain   = "vpc"

  tags = merge(local.common_tags, {
    Name     = "${each.value.node_name}-eip-${each.value.eip_index}"
    Workload = each.value.workload
  })

  depends_on = [
    aws_internet_gateway.this
  ]
}

resource "aws_eip_association" "zoom_node" {
  for_each             = local.node_eip_records
  allocation_id        = aws_eip.zoom_node[each.key].id
  network_interface_id = aws_network_interface.zoom_node[each.value.node_key].id
  private_ip_address   = each.value.private_ip
}
