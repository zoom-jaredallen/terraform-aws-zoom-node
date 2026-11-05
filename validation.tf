data "aws_servicequotas_service_quota" "ec2_elastic_ips" {
  service_code = "ec2"
  quota_code   = "L-0263D0A3"
}

data "aws_eips" "current" {}

data "aws_eips" "managed" {
  count = local.required_elastic_ips > 0 ? 1 : 0

  filter {
    name   = "tag:ManagedBy"
    values = ["Terraform"]
  }

  filter {
    name   = "tag:Name"
    values = local.desired_elastic_ip_names
  }
}

data "aws_ec2_instance_type_offerings" "selected" {
  for_each = local.selected_instance_type_availability_zones

  location_type = "availability-zone"

  filter {
    name   = "instance-type"
    values = [each.value.instance_type]
  }

  filter {
    name   = "location"
    values = [each.value.availability_zone]
  }
}

data "aws_ami" "selected" {
  for_each = local.selected_image_ids

  filter {
    name   = "image-id"
    values = [each.value]
  }
}

locals {
  supported_advanced_security_profiles = toset([
    "meetings_hybrid",
    "kubernetes_master",
    "kubernetes_worker",
  ])

  supported_security_group_egress_profiles = toset([
    "allow_all",
    "workload_specific",
    "deny_all",
  ])

  supported_cloudwatch_log_retention_days = toset([
    0, 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731,
    1096, 1827, 2192, 2557, 2922, 3288, 3653,
  ])

  node_ip_allocations = flatten([
    for node_key, node in local.node_records : [
      for ip in local.node_eni_private_ips[node_key] : "${node.subnet_tier}:${node.subnet_index}:${ip}"
    ]
  ])

  control_plane_virtual_ip_owner_exists = var.control_plane_virtual_ip != null && contains(
    keys(local.node_records),
    local.normalized_control_plane_virtual_ip.owner_node_key
  )
  control_plane_virtual_ip_owner_subnet_cidr = try(
    local.node_subnet_cidrs[local.normalized_control_plane_virtual_ip.owner_node_key],
    null
  )
  control_plane_virtual_ip_address_number = try(sum([
    for octet_index, octet in split(".", local.normalized_control_plane_virtual_ip.address) :
    tonumber(octet) * pow(256, 3 - octet_index)
  ]), null)
  control_plane_virtual_ip_subnet_first = try(sum([
    for octet_index, octet in split(".", cidrhost(local.control_plane_virtual_ip_owner_subnet_cidr, 0)) :
    tonumber(octet) * pow(256, 3 - octet_index)
  ]), null)
  control_plane_virtual_ip_subnet_last = try(sum([
    for octet_index, octet in split(".", cidrhost(local.control_plane_virtual_ip_owner_subnet_cidr, -1)) :
    tonumber(octet) * pow(256, 3 - octet_index)
  ]), null)
  control_plane_virtual_ip_in_owner_subnet = try(
    local.control_plane_virtual_ip_address_number >= local.control_plane_virtual_ip_subnet_first &&
    local.control_plane_virtual_ip_address_number <= local.control_plane_virtual_ip_subnet_last,
    false
  )
  control_plane_virtual_ip_is_usable = try(
    local.control_plane_virtual_ip_address_number > local.control_plane_virtual_ip_subnet_first + 3 &&
    local.control_plane_virtual_ip_address_number < local.control_plane_virtual_ip_subnet_last,
    false
  )
  control_plane_virtual_ip_validation_errors = var.control_plane_virtual_ip == null ? [] : concat(
    local.normalized_control_plane_virtual_ip.assignment_mode != "node" ? [
      "control_plane_virtual_ip.assignment_mode must be node; load_balancer is reserved for a future release."
    ] : [],
    !local.control_plane_virtual_ip_address_valid ? [
      "control_plane_virtual_ip.address must be a valid IPv4 address."
    ] : [],
    !local.control_plane_virtual_ip_owner_exists ? [
      "control_plane_virtual_ip.owner_node_key must identify an existing node."
    ] : [],
    local.control_plane_virtual_ip_owner_exists && try(local.node_records[local.normalized_control_plane_virtual_ip.owner_node_key].role, "") != "kubernetes_master" ? [
      "control_plane_virtual_ip.owner_node_key must identify a kubernetes_master node."
    ] : [],
    local.control_plane_virtual_ip_owner_exists && try(local.node_records[local.normalized_control_plane_virtual_ip.owner_node_key].source_dest_check, false) ? [
      "control_plane_virtual_ip requires source_dest_check=false on its owner node."
    ] : [],
    local.control_plane_virtual_ip_address_valid && local.control_plane_virtual_ip_owner_exists && !local.control_plane_virtual_ip_in_owner_subnet ? [
      "control_plane_virtual_ip.address must be inside the owner node's selected subnet."
    ] : [],
    local.control_plane_virtual_ip_address_valid && local.control_plane_virtual_ip_owner_exists && local.control_plane_virtual_ip_in_owner_subnet && !local.control_plane_virtual_ip_is_usable ? [
      "control_plane_virtual_ip.address must not use an AWS-reserved subnet address."
    ] : [],
    local.control_plane_virtual_ip_address_valid && contains(flatten(values(local.node_private_ips)), local.normalized_control_plane_virtual_ip.address) ? [
      "control_plane_virtual_ip.address overlaps a node bootstrap private IP."
    ] : []
  )

  advanced_ip_range_validation_errors = [
    for group_key, group in var.node_groups :
    "node_groups.${group_key} static IP range exceeds the selected subnet."
    if group.count > 0 && group.private_ip_start_offset + ((group.count - 1) * max(10, group.private_ips_per_node)) + group.private_ips_per_node >= pow(2, 32 - try(tonumber(split("/", group.subnet_tier == "private" ? local.configured_private_subnet_cidrs[group.subnet_index != null ? group.subnet_index : 0] : local.configured_public_subnet_cidrs[group.subnet_index != null ? group.subnet_index : 0])[1]), 32)) - 1
  ]

  advanced_node_group_validation_errors = flatten([
    for group_key, group in var.node_groups : concat(
      group.count < 0 || floor(group.count) != group.count ? ["node_groups.${group_key} count must be a non-negative integer."] : [],
      group.count > 0 ? concat(
        group.root_volume_gb <= 0 ? ["node_groups.${group_key} root_volume_gb must be greater than zero."] : [],
        group.private_ips_per_node <= 0 ? ["node_groups.${group_key} private_ips_per_node must be greater than zero."] : [],
        group.elastic_ips_per_node > group.private_ips_per_node ? ["node_groups.${group_key} elastic_ips_per_node cannot exceed private_ips_per_node."] : [],
        group.metadata_http_put_response_hop_limit != null && (group.metadata_http_put_response_hop_limit < 1 || group.metadata_http_put_response_hop_limit > 64) ? ["node_groups.${group_key} metadata_http_put_response_hop_limit must be between 1 and 64."] : [],
        !contains(["public", "private"], group.subnet_tier) ? ["node_groups.${group_key} subnet_tier must be public or private."] : [],
        group.subnet_index != null && (group.subnet_index < 0 || floor(group.subnet_index) != group.subnet_index) ? ["node_groups.${group_key} subnet_index must be a non-negative integer."] : [],
        group.purchase_option != null && !contains(["on_demand", "spot"], group.purchase_option) ? ["node_groups.${group_key} purchase_option must be on_demand or spot."] : [],
        group.instance_create_timeout != null && (trimspace(group.instance_create_timeout) == "" || !can(regex("^([0-9]+h)?([0-9]+m)?([0-9]+s)?$", group.instance_create_timeout))) ? ["node_groups.${group_key}.instance_create_timeout must be a Terraform duration such as 5m or 1h30m."] : [],
        group.image_channel != null && !contains(["prod", "dev"], group.image_channel) ? ["node_groups.${group_key} image_channel must be prod or dev."] : [],
        !contains(local.supported_advanced_security_profiles, group.security_profile) ? ["node_groups.${group_key} security_profile is not supported."] : [],
        group.image_id != null && trimspace(group.image_id) != "" && !can(regex("^ami-([0-9a-f]{8}|[0-9a-f]{17})$", trimspace(group.image_id))) ? ["node_groups.${group_key} image_id is not a valid AMI ID."] : []
      ) : []
    )
  ])

  explicit_node_subnet_bounds = {
    for node_key, _ in var.explicit_nodes : node_key => {
      first = sum([
        for octet_index, octet in split(".", cidrhost(local.node_subnet_cidrs[node_key], 0)) :
        tonumber(octet) * pow(256, 3 - octet_index)
      ])
      last = sum([
        for octet_index, octet in split(".", cidrhost(local.node_subnet_cidrs[node_key], -1)) :
        tonumber(octet) * pow(256, 3 - octet_index)
      ])
    }
  }

  explicit_node_validation_errors = flatten([
    for node_key, node in var.explicit_nodes : concat(
      trimspace(node_key) == "" ? ["explicit_nodes keys must not be empty."] : [],
      node.root_volume_gb <= 0 ? ["explicit_nodes.${node_key}.root_volume_gb must be greater than zero."] : [],
      length(node.private_ips) == 0 ? ["explicit_nodes.${node_key}.private_ips must not be empty."] : [],
      node.elastic_ips_per_node > length(node.private_ips) ? ["explicit_nodes.${node_key}.elastic_ips_per_node cannot exceed the number of private_ips."] : [],
      node.metadata_http_put_response_hop_limit != null && (node.metadata_http_put_response_hop_limit < 1 || node.metadata_http_put_response_hop_limit > 64) ? ["explicit_nodes.${node_key}.metadata_http_put_response_hop_limit must be between 1 and 64."] : [],
      !contains(["public", "private"], node.subnet_tier) ? ["explicit_nodes.${node_key}.subnet_tier must be public or private."] : [],
      node.subnet_index != null && (node.subnet_index < 0 || floor(node.subnet_index) != node.subnet_index) ? ["explicit_nodes.${node_key}.subnet_index must be a non-negative integer."] : [],
      node.purchase_option != null && !contains(["on_demand", "spot"], node.purchase_option) ? ["explicit_nodes.${node_key}.purchase_option must be on_demand or spot."] : [],
      node.instance_create_timeout != null && (trimspace(node.instance_create_timeout) == "" || !can(regex("^([0-9]+h)?([0-9]+m)?([0-9]+s)?$", node.instance_create_timeout))) ? ["explicit_nodes.${node_key}.instance_create_timeout must be a Terraform duration such as 5m or 1h30m."] : [],
      node.image_channel != null && !contains(["prod", "dev"], node.image_channel) ? ["explicit_nodes.${node_key}.image_channel must be prod or dev."] : [],
      node.image_id != null && trimspace(node.image_id) != "" && !can(regex("^ami-([0-9a-f]{8}|[0-9a-f]{17})$", trimspace(node.image_id))) ? ["explicit_nodes.${node_key}.image_id is not a valid AMI ID."] : [],
      node.security_profile == null && length(node.security_group_ids) == 0 ? ["explicit_nodes.${node_key} requires security_profile or security_group_ids."] : [],
      node.security_profile != null && length(node.security_group_ids) > 0 ? ["explicit_nodes.${node_key} cannot set both security_profile and security_group_ids."] : [],
      node.security_profile != null && !contains(local.supported_advanced_security_profiles, node.security_profile) ? ["explicit_nodes.${node_key}.security_profile is not supported."] : [],
      node.iam_profile_key != null && node.iam_instance_profile_name != null ? ["explicit_nodes.${node_key} cannot set both iam_profile_key and iam_instance_profile_name."] : [],
      [
        for ip in node.private_ips : "explicit_nodes.${node_key} private IP ${ip} is outside the selected subnet."
        if !try(
          sum([
            for octet_index, octet in split(".", ip) :
            tonumber(octet) * pow(256, 3 - octet_index)
          ]) >= local.explicit_node_subnet_bounds[node_key].first &&
          sum([
            for octet_index, octet in split(".", ip) :
            tonumber(octet) * pow(256, 3 - octet_index)
          ]) <= local.explicit_node_subnet_bounds[node_key].last,
          false
        )
      ]
    )
  ])

  all_declared_node_keys = concat(
    keys(local.workload_node_records),
    keys(local.advanced_node_records),
    keys(local.explicit_node_records)
  )
  colliding_node_keys = sort(distinct([
    for node_key in local.all_declared_node_keys : node_key
    if length([for candidate in local.all_declared_node_keys : candidate if candidate == node_key]) > 1
  ]))

  capacity_validation_errors = [
    for workload_type, workload in local.enabled_workloads :
    "${workload_type} requires capacity greater than 0."
    if local.workload_defaults[workload_type].capacity_sized && workload.capacity_value <= 0
  ]

  ip_validation_errors = [
    for workload_type, workload in local.enabled_workloads :
    "${workload_type} elastic_ips_per_node cannot exceed private_ips_per_eni."
    if workload.elastic_ips_per_node > workload.private_ips_per_eni
  ]

  unrestricted_management_cidrs = [
    for cidr in concat(var.source_cidrs.remote_management_1, var.source_cidrs.remote_management_2) : cidr
    if cidr == "0.0.0.0/0"
  ]

  required_elastic_ips = sum(concat([0], [
    for _, node in local.node_records : node.elastic_ips_per_node
  ])) + (var.aws.create_nat_gateway ? 1 : 0)
  desired_elastic_ip_names = concat(
    [for _, record in local.node_eip_records : "${record.node_name}-eip-${record.eip_index}"],
    var.aws.create_nat_gateway ? [var.environment_name == "" ? "zoom-node-nat-eip" : "${var.environment_name}-zoom-node-nat-eip"] : []
  )
  current_elastic_ips      = length(data.aws_eips.current.public_ips)
  managed_elastic_ips      = local.required_elastic_ips > 0 ? length(data.aws_eips.managed[0].public_ips) : 0
  required_new_elastic_ips = max(0, local.required_elastic_ips - local.managed_elastic_ips)
  eip_quota                = floor(data.aws_servicequotas_service_quota.ec2_elastic_ips.value)

  instance_type_validation_errors = [
    for pair_key, offerings in data.aws_ec2_instance_type_offerings.selected :
    "EC2 instance type ${local.selected_instance_type_availability_zones[pair_key].instance_type} is not offered in Availability Zone ${local.selected_instance_type_availability_zones[pair_key].availability_zone}. Choose another Availability Zone or a compatible instance type."
    if length(offerings.instance_types) == 0
  ]

  invalid_resolved_image_nodes = sort([
    for node_key, node in local.node_records : node_key
    if trimspace(node.image_id) != "" && !can(regex("^ami-([0-9a-f]{8}|[0-9a-f]{17})$", trimspace(node.image_id)))
  ])

  image_lookup_validation_errors = flatten([
    for image_id, image in data.aws_ami.selected : concat(
      image.state != "available" ? ["AMI ${image_id} is ${image.state}; it must be available in ${data.aws_region.current.region}."] : [],
      image.architecture != "x86_64" ? ["AMI ${image_id} uses ${image.architecture}; Zoom Node requires x86_64."] : []
    )
  ])

  unknown_node_image_keys = sort(tolist(setsubtract(
    toset(keys(var.node_image_ids)),
    toset(keys(local.node_records))
  )))

  invalid_node_image_ids = sort([
    for node_key, image_id in var.node_image_ids : node_key
    if !can(regex("^ami-([0-9a-f]{8}|[0-9a-f]{17})$", trimspace(image_id)))
  ])

  network_interface_validation_errors = [
    for node_key, interface_name in local.node_network_interface_names :
    "${node_key} instance type ${local.node_records[node_key].instance_type} has no network interface name in instance-catalog.json or AWS overrides."
    if trimspace(interface_name) == ""
  ]

  unknown_node_source_dest_check_keys = sort(tolist(setsubtract(
    toset(keys(var.aws.node_source_dest_check)),
    toset(keys(local.node_records))
  )))

  unknown_node_instance_create_timeout_keys = sort(tolist(setsubtract(
    toset(keys(var.aws.node_instance_create_timeouts)),
    toset(keys(local.node_records))
  )))

  unknown_security_group_egress_profile_keys = sort(tolist(setsubtract(
    toset(keys(var.aws.security_group_egress_profiles)),
    toset(keys(local.security_group_configs))
  )))

  invalid_security_group_egress_profiles = sort([
    for security_group_key, profile in var.aws.security_group_egress_profiles : security_group_key
    if !contains(local.supported_security_group_egress_profiles, profile)
  ])

  unknown_s3_iam_profile_keys = sort(tolist(setsubtract(
    toset(flatten([
      for _, access in var.aws.s3_bucket_access : tolist(access.iam_profile_keys)
    ])),
    toset(keys(local.iam_profile_configs))
  )))

  invalid_s3_bucket_access = flatten([
    for access_key, access in var.aws.s3_bucket_access : concat(
      !contains(["create_new", "use_existing"], access.mode) ? ["aws.s3_bucket_access.${access_key}.mode must be create_new or use_existing."] : [],
      trimspace(access.bucket_name) == "" ? ["aws.s3_bucket_access.${access_key}.bucket_name must not be empty."] : [],
      length(access.iam_profile_keys) == 0 ? ["aws.s3_bucket_access.${access_key}.iam_profile_keys must not be empty."] : [],
      length(access.actions) == 0 ? ["aws.s3_bucket_access.${access_key}.actions must not be empty."] : [],
      access.lifecycle_expiration_days != null && (access.lifecycle_expiration_days <= 0 || floor(access.lifecycle_expiration_days) != access.lifecycle_expiration_days) ? ["aws.s3_bucket_access.${access_key}.lifecycle_expiration_days must be a positive integer."] : [],
      access.lifecycle_noncurrent_version_expiration_days != null && (access.lifecycle_noncurrent_version_expiration_days <= 0 || floor(access.lifecycle_noncurrent_version_expiration_days) != access.lifecycle_noncurrent_version_expiration_days) ? ["aws.s3_bucket_access.${access_key}.lifecycle_noncurrent_version_expiration_days must be a positive integer."] : [],
      access.lifecycle_noncurrent_version_expiration_days != null && !access.versioning_enabled ? ["aws.s3_bucket_access.${access_key}.lifecycle_noncurrent_version_expiration_days requires versioning_enabled=true."] : []
    )
  ])

  validation_errors = concat(
    [
      for node_key, node in local.node_records :
      "${node_key} requires a customer-accessible AMI for channel ${node.image_channel} in ${data.aws_region.current.region}. Set image_ids.${node.image_channel}[\"${data.aws_region.current.region}\"], an exact image_id override, aws.image_id, or the legacy aws.image_ids entry."
      if trimspace(node.image_id) == ""
    ],
    length(local.colliding_node_keys) > 0 ? [
      "workload, node group, and explicit node keys must be unique: ${join(", ", local.colliding_node_keys)}."
    ] : [],
    length(local.unknown_node_image_keys) > 0 ? [
      "node_image_ids contains unknown node keys: ${join(", ", local.unknown_node_image_keys)}."
    ] : [],
    length(local.invalid_node_image_ids) > 0 ? [
      "node_image_ids contains invalid AMI IDs for: ${join(", ", local.invalid_node_image_ids)}."
    ] : [],
    length(local.invalid_resolved_image_nodes) > 0 ? [
      "Resolved image IDs are invalid for nodes: ${join(", ", local.invalid_resolved_image_nodes)}. Use an AMI ID such as ami-0123456789abcdef0."
    ] : [],
    length(local.unknown_node_source_dest_check_keys) > 0 ? [
      "aws.node_source_dest_check contains unknown node keys: ${join(", ", local.unknown_node_source_dest_check_keys)}."
    ] : [],
    trimspace(var.aws.instance_create_timeout) == "" || !can(regex("^([0-9]+h)?([0-9]+m)?([0-9]+s)?$", var.aws.instance_create_timeout)) ? [
      "aws.instance_create_timeout must be a Terraform duration such as 5m or 1h30m."
    ] : [],
    length([
      for node_key, duration in var.aws.node_instance_create_timeouts : node_key
      if trimspace(duration) == "" || !can(regex("^([0-9]+h)?([0-9]+m)?([0-9]+s)?$", duration))
      ]) > 0 ? [
      "aws.node_instance_create_timeouts values must be Terraform durations such as 5m or 1h30m."
    ] : [],
    length(local.unknown_node_instance_create_timeout_keys) > 0 ? [
      "aws.node_instance_create_timeouts contains unknown node keys: ${join(", ", local.unknown_node_instance_create_timeout_keys)}."
    ] : [],
    length(local.unknown_security_group_egress_profile_keys) > 0 ? [
      "aws.security_group_egress_profiles contains unknown security profile keys: ${join(", ", local.unknown_security_group_egress_profile_keys)}."
    ] : [],
    length(local.invalid_security_group_egress_profiles) > 0 ? [
      "aws.security_group_egress_profiles must use allow_all, workload_specific, or deny_all for: ${join(", ", local.invalid_security_group_egress_profiles)}."
    ] : [],
    length(local.unknown_s3_iam_profile_keys) > 0 ? [
      "aws.s3_bucket_access references unknown IAM profile keys: ${join(", ", local.unknown_s3_iam_profile_keys)}."
    ] : [],
    var.deployment_mode == "private_cloud" ? [
      "private_cloud is not implemented in the AWS Terraform MVP. Use public_cloud for initial testing."
    ] : [],
    length(var.source_cidrs.remote_management_1) + length(var.source_cidrs.remote_management_2) == 0 ? [
      "At least one remote management CIDR is required for TCP/8443 access."
    ] : [],
    length(local.unrestricted_management_cidrs) > 0 ? [
      "remote management CIDRs must not include 0.0.0.0/0."
    ] : [],
    var.network_mode == "use_existing" && trimspace(var.aws.existing_vpc_id) == "" ? [
      "network_mode=use_existing requires aws.existing_vpc_id."
    ] : [],
    var.network_mode == "use_existing" && length(var.aws.existing_subnet_ids) < local.requested_public_subnet_count ? [
      "network_mode=use_existing requires enough aws.existing_subnet_ids for availability_zone_config and explicit node group subnet indexes."
    ] : [],
    var.network_mode != "create_new" && local.requires_private_subnets ? [
      "private nodes require network_mode=create_new."
    ] : [],
    var.aws.create_nat_gateway && !local.requires_private_subnets ? [
      "aws.create_nat_gateway requires at least one private node group."
    ] : [],
    var.aws.create_nat_gateway && (!local.create_new_network || var.deployment_mode != "public_cloud" || !local.requires_public_subnets) ? [
      "aws.create_nat_gateway requires create_new public_cloud networking and at least one public node group."
    ] : [],
    length(local.node_ip_allocations) != length(distinct(local.node_ip_allocations)) ? [
      "node static IP ranges overlap."
    ] : [],
    !var.generate_node_password && !local.node_password_supplied ? [
      "Set node_password or enable generate_node_password."
    ] : [],
    var.generate_node_password && local.node_password_supplied ? [
      "node_password must be omitted when generate_node_password is true."
    ] : [],
    !contains(["on_demand", "spot"], var.aws.purchase_option) ? [
      "aws.purchase_option must be on_demand or spot."
    ] : [],
    var.aws.metadata_http_put_response_hop_limit < 1 || var.aws.metadata_http_put_response_hop_limit > 64 ? [
      "aws.metadata_http_put_response_hop_limit must be between 1 and 64."
    ] : [],
    var.aws.root_volume_kms_key_id != null && !var.aws.root_volume_encrypted ? [
      "aws.root_volume_kms_key_id requires root_volume_encrypted=true."
    ] : [],
    !contains(local.supported_cloudwatch_log_retention_days, var.aws.cloudwatch_log_retention_days) ? [
      "aws.cloudwatch_log_retention_days must be a supported CloudWatch Logs retention value."
    ] : [],
    local.hybrid_recording_enabled && !local.dedicated_hybrid_recording_s3_configured && !local.generic_hybrid_recording_s3_configured ? [
      "Hybrid Recording requires aws.s3_bucket_access[\"hybrid_recording\"] or the deprecated hybrid_recording_s3_bucket_name."
    ] : [],
    local.dedicated_hybrid_recording_s3_configured && local.generic_hybrid_recording_s3_configured ? [
      "Configure Hybrid Recording storage with either aws.s3_bucket_access[\"hybrid_recording\"] or the deprecated dedicated inputs, not both."
    ] : [],
    local.generic_hybrid_recording_s3_configured && !try(contains(var.aws.s3_bucket_access["hybrid_recording"].iam_profile_keys, "HybridRecording"), false) ? [
      "aws.s3_bucket_access[\"hybrid_recording\"].iam_profile_keys must include HybridRecording."
    ] : [],
    length(var.aws.hybrid_recording_s3_actions) == 0 ? [
      "aws.hybrid_recording_s3_actions must not be empty."
    ] : [],
    var.aws.hybrid_recording_s3_lifecycle_expiration_days != null && (var.aws.hybrid_recording_s3_lifecycle_expiration_days <= 0 || floor(var.aws.hybrid_recording_s3_lifecycle_expiration_days) != var.aws.hybrid_recording_s3_lifecycle_expiration_days) ? [
      "aws.hybrid_recording_s3_lifecycle_expiration_days must be a positive integer."
    ] : [],
    var.aws.hybrid_recording_s3_lifecycle_noncurrent_version_expiration_days != null && (var.aws.hybrid_recording_s3_lifecycle_noncurrent_version_expiration_days <= 0 || floor(var.aws.hybrid_recording_s3_lifecycle_noncurrent_version_expiration_days) != var.aws.hybrid_recording_s3_lifecycle_noncurrent_version_expiration_days) ? [
      "aws.hybrid_recording_s3_lifecycle_noncurrent_version_expiration_days must be a positive integer."
    ] : [],
    var.aws.hybrid_recording_s3_lifecycle_noncurrent_version_expiration_days != null && !var.aws.hybrid_recording_s3_versioning_enabled ? [
      "aws.hybrid_recording_s3_lifecycle_noncurrent_version_expiration_days requires versioning_enabled=true."
    ] : [],
    local.capacity_validation_errors,
    local.ip_validation_errors,
    local.advanced_node_group_validation_errors,
    local.advanced_ip_range_validation_errors,
    local.explicit_node_validation_errors,
    local.control_plane_virtual_ip_validation_errors,
    local.invalid_s3_bucket_access,
    local.network_interface_validation_errors,
    local.instance_type_validation_errors,
    local.image_lookup_validation_errors,
    local.required_new_elastic_ips > 0 && local.current_elastic_ips + local.required_new_elastic_ips > local.eip_quota ? [
      "Elastic IP quota is insufficient: current usage ${local.current_elastic_ips}, required new Elastic IPs ${local.required_new_elastic_ips}, quota ${local.eip_quota}."
    ] : []
  )
}

resource "terraform_data" "validation" {
  input = local.validation_errors

  lifecycle {
    precondition {
      condition     = length(local.validation_errors) == 0
      error_message = join("\n", local.validation_errors)
    }
  }
}
