# Retain moved blocks for the lifetime of a major release so consumers can
# safely skip intermediate versions. See docs/terraform-upgrades.md.

moved {
  from = aws_vpc.this
  to   = module.network.aws_vpc.this
}
moved {
  from = aws_internet_gateway.this
  to   = module.network.aws_internet_gateway.this
}
moved {
  from = aws_subnet.zoom_node
  to   = module.network.aws_subnet.zoom_node
}
moved {
  from = aws_subnet.private
  to   = module.network.aws_subnet.private
}
moved {
  from = aws_route_table.public
  to   = module.network.aws_route_table.public
}
moved {
  from = aws_route_table_association.public
  to   = module.network.aws_route_table_association.public
}
moved {
  from = aws_eip.nat
  to   = module.network.aws_eip.nat
}
moved {
  from = aws_nat_gateway.this
  to   = module.network.aws_nat_gateway.this
}
moved {
  from = aws_route_table.private
  to   = module.network.aws_route_table.private
}
moved {
  from = aws_route_table_association.private
  to   = module.network.aws_route_table_association.private
}

moved {
  from = aws_security_group.zoom_node
  to   = module.node.aws_security_group.zoom_node
}
moved {
  from = aws_vpc_security_group_ingress_rule.zoom_node
  to   = module.node.aws_vpc_security_group_ingress_rule.zoom_node
}
moved {
  from = aws_vpc_security_group_egress_rule.zoom_node
  to   = module.node.aws_vpc_security_group_egress_rule.zoom_node
}
moved {
  from = aws_network_interface.zoom_node
  to   = module.node.aws_network_interface.zoom_node
}
moved {
  from = aws_cloudwatch_log_group.zoom_node
  to   = module.node.aws_cloudwatch_log_group.zoom_node
}
moved {
  from = aws_instance.zoom_node
  to   = module.node.aws_instance.zoom_node
}
moved {
  from = aws_eip.zoom_node
  to   = module.node.aws_eip.zoom_node
}
moved {
  from = aws_eip_association.zoom_node
  to   = module.node.aws_eip_association.zoom_node
}

moved {
  from = aws_s3_bucket.hybrid_recording
  to   = module.storage_access.aws_s3_bucket.hybrid_recording
}
moved {
  from = aws_s3_bucket_public_access_block.hybrid_recording
  to   = module.storage_access.aws_s3_bucket_public_access_block.hybrid_recording
}
moved {
  from = aws_s3_bucket_server_side_encryption_configuration.hybrid_recording
  to   = module.storage_access.aws_s3_bucket_server_side_encryption_configuration.hybrid_recording
}
moved {
  from = aws_s3_bucket_versioning.hybrid_recording
  to   = module.storage_access.aws_s3_bucket_versioning.hybrid_recording
}
moved {
  from = aws_s3_bucket_lifecycle_configuration.hybrid_recording
  to   = module.storage_access.aws_s3_bucket_lifecycle_configuration.hybrid_recording
}
moved {
  from = aws_s3_bucket.node_group
  to   = module.storage_access.aws_s3_bucket.node_group
}
moved {
  from = aws_s3_bucket_public_access_block.node_group
  to   = module.storage_access.aws_s3_bucket_public_access_block.node_group
}
moved {
  from = aws_s3_bucket_server_side_encryption_configuration.node_group
  to   = module.storage_access.aws_s3_bucket_server_side_encryption_configuration.node_group
}
moved {
  from = aws_s3_bucket_versioning.node_group
  to   = module.storage_access.aws_s3_bucket_versioning.node_group
}
moved {
  from = aws_s3_bucket_lifecycle_configuration.node_group
  to   = module.storage_access.aws_s3_bucket_lifecycle_configuration.node_group
}
moved {
  from = aws_iam_role.zoom_node
  to   = module.storage_access.aws_iam_role.zoom_node
}
moved {
  from = aws_iam_instance_profile.zoom_node
  to   = module.storage_access.aws_iam_instance_profile.zoom_node
}
moved {
  from = aws_iam_role_policy.hybrid_recording_s3
  to   = module.storage_access.aws_iam_role_policy.hybrid_recording_s3
}
moved {
  from = aws_iam_role_policy.node_group_s3
  to   = module.storage_access.aws_iam_role_policy.node_group_s3
}
