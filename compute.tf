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

  node_availability_zones = {
    for node_key, node in local.node_records : node_key => (
      node.subnet_tier == "private" ? local.effective_private_subnet_availability_zones[node.subnet_index] : local.effective_public_subnet_availability_zones[node.subnet_index]
    )
  }

  selected_instance_type_availability_zone_keys = toset([
    for node_key, node in local.node_records : "${node.instance_type}|${local.node_availability_zones[node_key]}"
  ])

  selected_instance_type_availability_zones = {
    for pair_key in local.selected_instance_type_availability_zone_keys : pair_key => {
      instance_type     = split("|", pair_key)[0]
      availability_zone = split("|", pair_key)[1]
    }
  }

  capacity_request_groups = {
    for node_key, node in local.node_records :
    "${data.aws_region.current.region}|${local.node_availability_zones[node_key]}|${node.instance_type}|${node.purchase_option}" => {
      region            = data.aws_region.current.region
      availability_zone = local.node_availability_zones[node_key]
      instance_type     = node.instance_type
      market_type       = node.purchase_option == "on_demand" ? "on-demand" : "spot"
    }...
  }

  capacity_preflight_requests = [
    for request_key in sort(keys(local.capacity_request_groups)) : merge(
      local.capacity_request_groups[request_key][0],
      { instance_count = length(local.capacity_request_groups[request_key]) }
    )
  ]

  node_subnet_prefix_lengths = {
    for node_key, cidr in local.node_subnet_cidrs : node_key => tonumber(split("/", cidr)[1])
  }

  node_private_ips = {
    for node_key, node in local.node_records : node_key => (
      node.private_ips != null ? node.private_ips : [
        for ip_index in range(node.private_ips_per_eni) :
        cidrhost(local.node_subnet_cidrs[node_key], node.node_start_offset + (node.node_index * max(10, node.private_ips_per_eni)) + ip_index)
      ]
    )
  }

  normalized_control_plane_virtual_ip = var.control_plane_virtual_ip == null ? null : {
    address         = trimspace(var.control_plane_virtual_ip.address)
    assignment_mode = trimspace(var.control_plane_virtual_ip.assignment_mode)
    owner_node_key  = trimspace(var.control_plane_virtual_ip.owner_node_key)
  }

  control_plane_virtual_ip_address_valid = var.control_plane_virtual_ip != null && can(regex(
    "^([0-9]{1,3}\\.){3}[0-9]{1,3}$",
    trimspace(var.control_plane_virtual_ip.address)
  )) && try(cidrhost("${trimspace(var.control_plane_virtual_ip.address)}/32", 0) == trimspace(var.control_plane_virtual_ip.address), false)

  node_eni_private_ips = {
    for node_key, private_ips in local.node_private_ips : node_key => concat(
      private_ips,
      var.control_plane_virtual_ip != null &&
      local.control_plane_virtual_ip_address_valid &&
      local.normalized_control_plane_virtual_ip.assignment_mode == "node" &&
      local.normalized_control_plane_virtual_ip.owner_node_key == node_key ? [local.normalized_control_plane_virtual_ip.address] : []
    )
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
      for eip_index in range(min(node.elastic_ips_per_node, length(local.node_private_ips[node_key]))) : {
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
