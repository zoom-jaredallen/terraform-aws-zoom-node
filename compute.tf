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
