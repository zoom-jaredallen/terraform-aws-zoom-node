variable "environment_name" {
  type        = string
  default     = ""
  description = "Optional environment prefix for node names."
}

variable "domain_name" {
  type        = string
  description = "DNS domain appended to generated Zoom Node hostnames."

  validation {
    condition     = length(trimspace(var.domain_name)) > 0
    error_message = "domain_name is required."
  }
}

variable "deployment_mode" {
  type        = string
  default     = "public_cloud"
  description = "Zoom Node deployment mode. Use public_cloud for direct public IPs or private_cloud for private-only nodes."

  validation {
    condition     = contains(["public_cloud", "private_cloud"], var.deployment_mode)
    error_message = "deployment_mode must be public_cloud or private_cloud."
  }
}

variable "network_mode" {
  type        = string
  default     = "create_new"
  description = "Network mode. Use create_new to create a VPC/subnets or use_existing to supply VPC/subnet IDs."

  validation {
    condition     = contains(["create_new", "use_existing"], var.network_mode)
    error_message = "network_mode must be create_new or use_existing."
  }
}

variable "availability_zone_config" {
  type        = string
  default     = "single_az"
  description = "Node placement model."

  validation {
    condition     = contains(["single_az", "dual_az"], var.availability_zone_config)
    error_message = "availability_zone_config must be single_az or dual_az."
  }
}

variable "registration_code" {
  type        = string
  sensitive   = true
  description = "Fresh Zoom Node registration code used in bootstrap data for newly created nodes."

  validation {
    condition     = can(regex("^[A-Za-z0-9]{16}$", var.registration_code))
    error_message = "registration_code must be exactly 16 alphanumeric characters."
  }
}

variable "node_password" {
  type        = string
  default     = null
  sensitive   = true
  nullable    = true
  description = "Initial Zoom Node local administrator password used in bootstrap data. Required unless generate_node_password is true."

  validation {
    condition = var.node_password == null ? true : (
      length(var.node_password) >= 8 &&
      length(var.node_password) <= 16 &&
      can(regex("[A-Z]", var.node_password)) &&
      can(regex("[a-z]", var.node_password)) &&
      can(regex("[0-9]", var.node_password)) &&
      can(regex("[!.@%#*_%~?]", var.node_password)) &&
      can(regex("^[A-Za-z0-9!.@%#*_%~?]+$", var.node_password))
    )
    error_message = "node_password must be 8-16 characters and include at least one uppercase letter, one lowercase letter, one number, and one symbol from !.@%#*_%~?."
  }
}

variable "generate_node_password" {
  type        = bool
  default     = false
  description = "Generate a compliant 16-character Zoom Node password instead of accepting node_password."
}

variable "image_channel" {
  type        = string
  default     = "prod"
  description = "Image catalog channel. Use prod for hardened production images or dev for development images that support SSH access."

  validation {
    condition     = contains(["prod", "dev"], var.image_channel)
    error_message = "image_channel must be prod or dev."
  }
}

variable "node_image_ids" {
  type        = map(string)
  default     = {}
  description = "Optional AMI overrides keyed by stable Terraform node key, for example meetings_hybrid-01."
}

variable "workloads" {
  description = "Provider-neutral Zoom Node workload selection and capacity inputs."
  type = object({
    meetings_hybrid = optional(object({
      enabled                      = optional(bool, false)
      capacity                     = optional(number, 0)
      node_count_override          = optional(number, 0)
      node_private_ip_start_offset = optional(number, 10)
      instance_type                = optional(string, null)
      image_id                     = optional(string, null)
      root_volume_gb               = optional(number, null)
      private_ips_per_eni          = optional(number, null)
      elastic_ips_per_node         = optional(number, null)
    }), {})
    hybrid_recording = optional(object({
      enabled                      = optional(bool, false)
      capacity                     = optional(number, 0)
      node_count_override          = optional(number, 0)
      node_private_ip_start_offset = optional(number, 110)
      instance_type                = optional(string, null)
      image_id                     = optional(string, null)
      root_volume_gb               = optional(number, null)
      private_ips_per_eni          = optional(number, null)
      elastic_ips_per_node         = optional(number, null)
    }), {})
    meeting_survivability = optional(object({
      enabled                      = optional(bool, false)
      node_count                   = optional(number, 1)
      node_private_ip_start_offset = optional(number, 100)
      instance_type                = optional(string, null)
      image_id                     = optional(string, null)
      root_volume_gb               = optional(number, null)
      private_ips_per_eni          = optional(number, null)
      elastic_ips_per_node         = optional(number, null)
    }), {})
    web_application_gateway = optional(object({
      enabled                      = optional(bool, false)
      capacity                     = optional(number, 0)
      node_count_override          = optional(number, 0)
      node_private_ip_start_offset = optional(number, 120)
      instance_type                = optional(string, null)
      image_id                     = optional(string, null)
      root_volume_gb               = optional(number, null)
      private_ips_per_eni          = optional(number, null)
      elastic_ips_per_node         = optional(number, null)
    }), {})
    ai_services = optional(object({
      enabled                      = optional(bool, false)
      node_count                   = optional(number, 1)
      node_private_ip_start_offset = optional(number, 140)
      instance_type                = optional(string, null)
      image_id                     = optional(string, null)
      root_volume_gb               = optional(number, null)
      private_ips_per_eni          = optional(number, null)
      elastic_ips_per_node         = optional(number, null)
    }), {})
    phone_local_survivability = optional(object({
      enabled                      = optional(bool, false)
      capacity                     = optional(number, 0)
      node_count_override          = optional(number, 0)
      node_private_ip_start_offset = optional(number, 130)
      instance_type                = optional(string, null)
      image_id                     = optional(string, null)
      root_volume_gb               = optional(number, null)
      private_ips_per_eni          = optional(number, null)
      elastic_ips_per_node         = optional(number, null)
    }), {})
  })
  default = {}
}

variable "node_groups" {
  description = "Advanced heterogeneous Zoom Node groups. Use for infrastructure roles or lab topologies that do not follow workload capacity formulas."
  type = map(object({
    count                                = number
    role                                 = string
    hostname_prefix                      = string
    instance_type                        = string
    image_channel                        = optional(string, null)
    image_id                             = optional(string, null)
    root_volume_gb                       = number
    private_ips_per_node                 = optional(number, 1)
    elastic_ips_per_node                 = optional(number, 0)
    private_ip_start_offset              = number
    subnet_tier                          = string
    subnet_index                         = optional(number, null)
    purchase_option                      = optional(string, null)
    source_dest_check                    = optional(bool, true)
    metadata_http_put_response_hop_limit = optional(number, null)
    security_profile                     = string
    iam_profile_key                      = string
  }))
  default = {}
}

variable "explicit_nodes" {
  description = "Exact Zoom Node inventory keyed by stable Terraform node identity. Use for adopting existing nodes or preserving exact hostnames and private IPs."
  type = map(object({
    node_name                            = optional(string, null)
    fqdn                                 = optional(string, null)
    role                                 = string
    instance_type                        = string
    image_channel                        = optional(string, null)
    image_id                             = optional(string, null)
    root_volume_gb                       = number
    private_ips                          = list(string)
    elastic_ips_per_node                 = optional(number, 0)
    subnet_tier                          = string
    subnet_index                         = optional(number, null)
    purchase_option                      = optional(string, null)
    source_dest_check                    = optional(bool, true)
    metadata_http_put_response_hop_limit = optional(number, null)
    security_profile                     = optional(string, null)
    security_group_ids                   = optional(list(string), [])
    iam_profile_key                      = optional(string, null)
    iam_instance_profile_name            = optional(string, null)
  }))
  default = {}
}

variable "source_cidrs" {
  description = "Provider-neutral source CIDRs for workload traffic."
  type = object({
    zoom_clients        = optional(list(string), ["0.0.0.0/0"])
    zoom_cloud          = optional(list(string), ["0.0.0.0/0"])
    remote_management_1 = optional(list(string), [])
    remote_management_2 = optional(list(string), [])
    internal_traffic    = optional(list(string), [])
    nfs                 = optional(list(string), [])
    sbc                 = optional(list(string), [])
  })
  default = {}
}

variable "aws" {
  description = "AWS-specific settings kept behind the portable Zoom Node interface."
  type = object({
    image_id                                                         = optional(string, "")
    image_ids                                                        = optional(map(string), {})
    key_name                                                         = optional(string, null)
    vpc_cidr                                                         = optional(string, "10.0.0.0/16")
    subnet_cidrs                                                     = optional(list(string), [])
    public_subnet_cidrs                                              = optional(list(string), [])
    private_subnet_cidrs                                             = optional(list(string), [])
    create_nat_gateway                                               = optional(bool, false)
    availability_zones                                               = optional(list(string), [])
    existing_vpc_id                                                  = optional(string, "")
    existing_subnet_ids                                              = optional(list(string), [])
    subnet_newbits                                                   = optional(number, 8)
    dns_servers                                                      = optional(list(string), [])
    network_interface_name                                           = optional(string, "")
    network_interface_names_by_instance_type                         = optional(map(string), {})
    network_interface_names_by_instance_family                       = optional(map(string), {})
    metadata_http_put_response_hop_limit                             = optional(number, 3)
    node_source_dest_check                                           = optional(map(bool), {})
    instance_tags                                                    = optional(map(string), {})
    purchase_option                                                  = optional(string, "on_demand")
    root_volume_encrypted                                            = optional(bool, true)
    root_volume_kms_key_id                                           = optional(string, null)
    cloudwatch_log_retention_days                                    = optional(number, 30)
    cloudwatch_log_kms_key_id                                        = optional(string, null)
    iam_path                                                         = optional(string, "/")
    permissions_boundary                                             = optional(string, null)
    enable_public_ipv4_on_boot                                       = optional(bool, false)
    security_group_egress_profiles                                   = optional(map(string), {})
    hybrid_recording_s3_actions                                      = optional(set(string), ["s3:*"])
    hybrid_recording_s3_kms_key_arn                                  = optional(string, null)
    hybrid_recording_s3_versioning_enabled                           = optional(bool, false)
    hybrid_recording_s3_lifecycle_expiration_days                    = optional(number, null)
    hybrid_recording_s3_lifecycle_noncurrent_version_expiration_days = optional(number, null)
    s3_bucket_access = optional(map(object({
      bucket_name                                  = string
      mode                                         = optional(string, "use_existing")
      iam_profile_keys                             = set(string)
      actions                                      = optional(set(string), ["s3:*"])
      kms_key_arn                                  = optional(string, null)
      versioning_enabled                           = optional(bool, false)
      lifecycle_expiration_days                    = optional(number, null)
      lifecycle_noncurrent_version_expiration_days = optional(number, null)
    })), {})
  })
  default = {}
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Additional tags applied to all supported AWS resources."
}

variable "enable_least_privilege_egress" {
  type        = bool
  default     = false
  description = "Deprecated compatibility input. When true, standard workloads use workload_specific egress unless aws.security_group_egress_profiles sets an explicit profile."
}

variable "hybrid_recording_s3_bucket_name" {
  type        = string
  default     = ""
  description = "S3 bucket name used by Hybrid Recording. Required when Hybrid Recording is enabled."
}

variable "hybrid_recording_s3_bucket_mode" {
  type        = string
  default     = "use_existing"
  description = "Use create_new to create the Hybrid Recording bucket or use_existing to grant access to an existing bucket."

  validation {
    condition     = contains(["create_new", "use_existing"], var.hybrid_recording_s3_bucket_mode)
    error_message = "hybrid_recording_s3_bucket_mode must be create_new or use_existing."
  }
}
