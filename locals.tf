data "aws_region" "current" {}
data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  subnet_count = var.availability_zone_config == "dual_az" ? 2 : 1

  node_password_supplied  = nonsensitive(var.node_password != null)
  effective_node_password = var.generate_node_password ? random_password.node[0].result : (var.node_password != null ? var.node_password : "")

  image_catalog    = jsondecode(file("${path.module}/image-catalog.json"))
  instance_catalog = jsondecode(file("${path.module}/instance-catalog.json"))
  workload_catalog = jsondecode(file("${path.module}/workload-catalog.json"))

  catalog_network_interface_names_by_instance_type = {
    for instance_type, config in local.instance_catalog.aws :
    instance_type => config.network_interface_name
  }
  network_interface_names_by_instance_type = merge(
    local.catalog_network_interface_names_by_instance_type,
    var.aws.network_interface_names_by_instance_type
  )

  workload_defaults = {
    for workload_type, workload in local.workload_catalog.workloads :
    workload_type => {
      input_key                    = workload.input_key
      capacity_metric              = workload.capacity.metric
      capacity_per_node            = workload.capacity.per_node
      min_nodes                    = workload.capacity.min_nodes
      instance_type                = workload.provider_defaults.aws.instance_type
      vcpu                         = workload.resources.vcpu
      memory_gb                    = workload.resources.memory_gb
      root_volume_gb               = workload.resources.root_volume_gb
      enis_per_node                = workload.resources.enis_per_node
      private_ips_per_eni          = workload.resources.private_ips_per_node
      minimum_private_ips_per_eni  = workload.resources.private_ips_per_node
      elastic_ips_per_node         = workload.resources.public_ips_per_node.public_cloud
      minimum_elastic_ips_per_node = workload.resources.public_ips_per_node.public_cloud
      prefix                       = workload.prefix
      default_start_offset         = workload.default_start_offset
      capacity_sized               = workload.capacity.sized
      uses_s3_storage              = workload.features.uses_s3_storage
      uses_managed_redis           = workload.features.uses_managed_redis
      services_co_resident         = workload.features.services_co_resident
    }
  }

  workload_configs = {
    for workload_type, defaults in local.workload_defaults :
    workload_type => var.workloads[defaults.input_key]
  }

  enabled_workloads = {
    for workload_type, defaults in local.workload_defaults :
    workload_type => {
      input_key            = defaults.input_key
      prefix               = defaults.prefix
      capacity_metric      = defaults.capacity_metric
      capacity_value       = try(local.workload_configs[workload_type].capacity, try(local.workload_configs[workload_type].node_count, 0))
      capacity_per_node    = defaults.capacity_per_node
      min_nodes            = defaults.min_nodes
      node_count           = defaults.capacity_sized ? max(defaults.min_nodes, try(local.workload_configs[workload_type].node_count_override, 0) > 0 ? local.workload_configs[workload_type].node_count_override : ceil(max(try(local.workload_configs[workload_type].capacity, 0), 1) / defaults.capacity_per_node)) : max(defaults.min_nodes, try(local.workload_configs[workload_type].node_count, defaults.min_nodes))
      instance_type        = coalesce(try(local.workload_configs[workload_type].instance_type, null), defaults.instance_type)
      image_id             = try(local.workload_configs[workload_type].image_id, null) != null && trimspace(local.workload_configs[workload_type].image_id) != "" ? trimspace(local.workload_configs[workload_type].image_id) : trimspace(var.aws.image_id) != "" ? trimspace(var.aws.image_id) : lookup(var.aws.image_ids, data.aws_region.current.region, try(local.image_catalog.aws[var.image_channel][data.aws_region.current.region], ""))
      root_volume_gb       = coalesce(try(local.workload_configs[workload_type].root_volume_gb, null), defaults.root_volume_gb)
      private_ips_per_eni  = max(defaults.minimum_private_ips_per_eni, coalesce(try(local.workload_configs[workload_type].private_ips_per_eni, null), defaults.private_ips_per_eni))
      elastic_ips_per_node = max(defaults.minimum_elastic_ips_per_node, coalesce(try(local.workload_configs[workload_type].elastic_ips_per_node, null), defaults.elastic_ips_per_node))
      node_start_offset    = coalesce(try(local.workload_configs[workload_type].node_private_ip_start_offset, null), defaults.default_start_offset)
      uses_s3_storage      = defaults.uses_s3_storage
      uses_managed_redis   = defaults.uses_managed_redis
      services_co_resident = defaults.services_co_resident
    }
    if try(local.workload_configs[workload_type].enabled, false)
  }

  workload_node_record_list = flatten([
    for workload_type, workload in local.enabled_workloads : [
      for node_index in range(workload.node_count) : {
        key                                  = "${workload.input_key}-${format("%02d", node_index + 1)}"
        workload_type                        = workload_type
        input_key                            = workload.input_key
        node_index                           = node_index
        node_number                          = node_index + 1
        subnet_index                         = var.availability_zone_config == "dual_az" ? node_index % 2 : 0
        prefix                               = workload.prefix
        node_name                            = var.environment_name == "" ? "${workload.prefix}-node${node_index + 1}" : "${var.environment_name}-${workload.prefix}-node${node_index + 1}"
        fqdn                                 = "${var.environment_name == "" ? "${workload.prefix}-node${node_index + 1}" : "${var.environment_name}-${workload.prefix}-node${node_index + 1}"}.${var.domain_name}"
        instance_type                        = workload.instance_type
        image_id                             = workload.image_id
        root_volume_gb                       = workload.root_volume_gb
        private_ips_per_eni                  = workload.private_ips_per_eni
        elastic_ips_per_node                 = var.deployment_mode == "public_cloud" ? workload.elastic_ips_per_node : 0
        node_start_offset                    = workload.node_start_offset
        role                                 = workload_type
        subnet_tier                          = "public"
        purchase_option                      = var.aws.purchase_option
        source_dest_check                    = lookup(var.aws.node_source_dest_check, "${workload.input_key}-${format("%02d", node_index + 1)}", true)
        metadata_http_put_response_hop_limit = var.aws.metadata_http_put_response_hop_limit
        security_profile                     = workload_type
        iam_profile_key                      = workload_type
        image_channel                        = var.image_channel
      }
    ]
  ])

  workload_node_records = {
    for node in local.workload_node_record_list : node.key => node
  }

  advanced_node_record_list = flatten([
    for group_key, group in var.node_groups : [
      for node_index in range(group.count) : {
        key           = "${group_key}-${format("%02d", node_index + 1)}"
        workload_type = group.role
        input_key     = group_key
        node_index    = node_index
        node_number   = node_index + 1
        subnet_index  = group.subnet_index != null ? group.subnet_index : (var.availability_zone_config == "dual_az" ? node_index % 2 : 0)
        prefix        = group.hostname_prefix
        node_name     = var.environment_name == "" ? "${group.hostname_prefix}-node${node_index + 1}" : "${var.environment_name}-${group.hostname_prefix}-node${node_index + 1}"
        fqdn          = "${var.environment_name == "" ? "${group.hostname_prefix}-node${node_index + 1}" : "${var.environment_name}-${group.hostname_prefix}-node${node_index + 1}"}.${var.domain_name}"
        instance_type = group.instance_type
        image_channel = group.image_channel != null ? group.image_channel : var.image_channel
        image_id = group.image_id != null && trimspace(group.image_id) != "" ? trimspace(group.image_id) : (
          group.image_channel != null ? try(local.image_catalog.aws[group.image_channel][data.aws_region.current.region], "") : (
            trimspace(var.aws.image_id) != "" ? trimspace(var.aws.image_id) : lookup(var.aws.image_ids, data.aws_region.current.region, try(local.image_catalog.aws[var.image_channel][data.aws_region.current.region], ""))
          )
        )
        root_volume_gb                       = group.root_volume_gb
        private_ips_per_eni                  = group.private_ips_per_node
        elastic_ips_per_node                 = var.deployment_mode == "public_cloud" ? group.elastic_ips_per_node : 0
        node_start_offset                    = group.private_ip_start_offset
        role                                 = group.role
        subnet_tier                          = group.subnet_tier
        purchase_option                      = group.purchase_option != null ? group.purchase_option : var.aws.purchase_option
        source_dest_check                    = group.source_dest_check
        metadata_http_put_response_hop_limit = group.metadata_http_put_response_hop_limit != null ? group.metadata_http_put_response_hop_limit : var.aws.metadata_http_put_response_hop_limit
        security_profile                     = group.security_profile
        iam_profile_key                      = group.iam_profile_key
      }
    ]
  ])

  advanced_node_records = {
    for node in local.advanced_node_record_list : node.key => node
  }

  combined_node_records = merge(local.workload_node_records, local.advanced_node_records)

  node_records = {
    for node_key, node in local.combined_node_records : node_key => merge(node, {
      image_id = lookup(var.node_image_ids, node.key, node.image_id)
    })
  }

  selected_instance_types = toset([
    for _, node in local.node_records : node.instance_type
  ])

  advanced_iam_profile_keys = toset([
    for _, group in var.node_groups : group.iam_profile_key
  ])

  legacy_iam_profile_configs = {
    for workload_type, workload in local.enabled_workloads : workload_type => {
      prefix = workload.prefix
      label  = workload_type
    }
  }

  advanced_iam_profile_configs = {
    for profile_key in local.advanced_iam_profile_keys : profile_key => {
      prefix = substr(replace(lower(profile_key), "/[^a-z0-9+=,.@_-]/", "-"), 0, 32)
      label  = profile_key
    }
  }

  iam_profile_configs = merge(
    local.legacy_iam_profile_configs,
    local.advanced_iam_profile_configs
  )

  advanced_security_profiles = toset([
    for _, group in var.node_groups : group.security_profile
  ])

  node_network_interface_names = {
    for node_key, node in local.node_records : node_key => (
      trimspace(var.aws.network_interface_name) != "" ?
      trimspace(var.aws.network_interface_name) :
      lookup(
        local.network_interface_names_by_instance_type,
        node.instance_type,
        lookup(
          var.aws.network_interface_names_by_instance_family,
          split(".", node.instance_type)[0],
          ""
        )
      )
    )
  }

  common_tags = merge(
    {
      Application = "Zoom-Node"
      ManagedBy   = "Terraform"
    },
    var.environment_name == "" ? {} : { Environment = var.environment_name },
    var.tags
  )
}
