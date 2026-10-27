#!/usr/bin/env bash
set -euo pipefail

for module in network node storage-access; do
  test -f "modules/${module}/main.tf" || {
    echo "Missing modules/${module}/main.tf" >&2
    exit 1
  }
done

required_moves=(
  'aws_vpc.this module.network.aws_vpc.this'
  'aws_internet_gateway.this module.network.aws_internet_gateway.this'
  'aws_subnet.zoom_node module.network.aws_subnet.zoom_node'
  'aws_subnet.private module.network.aws_subnet.private'
  'aws_route_table.public module.network.aws_route_table.public'
  'aws_route_table_association.public module.network.aws_route_table_association.public'
  'aws_eip.nat module.network.aws_eip.nat'
  'aws_nat_gateway.this module.network.aws_nat_gateway.this'
  'aws_route_table.private module.network.aws_route_table.private'
  'aws_route_table_association.private module.network.aws_route_table_association.private'
  'aws_security_group.zoom_node module.node.aws_security_group.zoom_node'
  'aws_vpc_security_group_ingress_rule.zoom_node module.node.aws_vpc_security_group_ingress_rule.zoom_node'
  'aws_vpc_security_group_egress_rule.zoom_node module.node.aws_vpc_security_group_egress_rule.zoom_node'
  'aws_network_interface.zoom_node module.node.aws_network_interface.zoom_node'
  'aws_cloudwatch_log_group.zoom_node module.node.aws_cloudwatch_log_group.zoom_node'
  'aws_instance.zoom_node module.node.aws_instance.zoom_node'
  'aws_eip.zoom_node module.node.aws_eip.zoom_node'
  'aws_eip_association.zoom_node module.node.aws_eip_association.zoom_node'
  'aws_s3_bucket.hybrid_recording module.storage_access.aws_s3_bucket.hybrid_recording'
  'aws_s3_bucket_public_access_block.hybrid_recording module.storage_access.aws_s3_bucket_public_access_block.hybrid_recording'
  'aws_s3_bucket_server_side_encryption_configuration.hybrid_recording module.storage_access.aws_s3_bucket_server_side_encryption_configuration.hybrid_recording'
  'aws_s3_bucket_versioning.hybrid_recording module.storage_access.aws_s3_bucket_versioning.hybrid_recording'
  'aws_s3_bucket_lifecycle_configuration.hybrid_recording module.storage_access.aws_s3_bucket_lifecycle_configuration.hybrid_recording'
  'aws_s3_bucket.node_group module.storage_access.aws_s3_bucket.node_group'
  'aws_s3_bucket_public_access_block.node_group module.storage_access.aws_s3_bucket_public_access_block.node_group'
  'aws_s3_bucket_server_side_encryption_configuration.node_group module.storage_access.aws_s3_bucket_server_side_encryption_configuration.node_group'
  'aws_s3_bucket_versioning.node_group module.storage_access.aws_s3_bucket_versioning.node_group'
  'aws_s3_bucket_lifecycle_configuration.node_group module.storage_access.aws_s3_bucket_lifecycle_configuration.node_group'
  'aws_iam_role.zoom_node module.storage_access.aws_iam_role.zoom_node'
  'aws_iam_instance_profile.zoom_node module.storage_access.aws_iam_instance_profile.zoom_node'
  'aws_iam_role_policy.hybrid_recording_s3 module.storage_access.aws_iam_role_policy.hybrid_recording_s3'
  'aws_iam_role_policy.node_group_s3 module.storage_access.aws_iam_role_policy.node_group_s3'
)

for move in "${required_moves[@]}"; do
  read -r from to <<<"${move}"
  (rg -F -q "from = ${from}" moved.tf && rg -F -q "to   = ${to}" moved.tf) || {
    echo "Missing moved block: ${from} -> ${to}" >&2
    exit 1
  }
done

for ignored_attribute in private_ips private_ip_list private_ip_list_enabled; do
  rg -q "ignore_changes = \[[^]]*${ignored_attribute}" modules/node/main.tf || {
    echo "Node ENI lifecycle must preserve legacy ${ignored_attribute} state during adoption." >&2
    exit 1
  }
done

echo "Module extraction contract passed."
