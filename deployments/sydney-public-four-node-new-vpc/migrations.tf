import {
  to = module.zoom_node.module.network.aws_vpc.this[0]
  id = "vpc-081b71423786fc0d2"
}

import {
  to = module.zoom_node.module.network.aws_internet_gateway.this[0]
  id = "igw-0f1a9645d8451c4ed"
}

import {
  to = module.zoom_node.module.network.aws_subnet.zoom_node[0]
  id = "subnet-00800f4d06bd5d5bb"
}

import {
  to = module.zoom_node.module.network.aws_route_table.public[0]
  id = "rtb-02b9833b1888f8a25"
}

import {
  to = module.zoom_node.module.network.aws_route_table_association.public[0]
  id = "subnet-00800f4d06bd5d5bb/rtb-02b9833b1888f8a25"
}

import {
  to = aws_security_group.zoom_node
  id = "sg-03bafcdd8e11c76f9"
}

import {
  for_each = local.nodes
  to       = module.zoom_node.module.node.aws_instance.zoom_node[each.key]
  id       = each.value.instance_id
}

import {
  for_each = local.nodes
  to       = module.zoom_node.module.node.aws_network_interface.zoom_node[each.key]
  id       = each.value.eni_id
}

import {
  for_each = local.nodes
  to       = module.zoom_node.module.node.aws_eip.zoom_node["${each.key}-eip-0"]
  id       = each.value.eip_allocation
}

import {
  for_each = local.nodes
  to       = module.zoom_node.module.node.aws_eip_association.zoom_node["${each.key}-eip-0"]
  id       = each.value.eip_association
}

import {
  for_each = local.nodes
  to       = module.zoom_node.module.node.aws_cloudwatch_log_group.zoom_node[each.key]
  id       = "/zoom-node/${each.key}"
}
