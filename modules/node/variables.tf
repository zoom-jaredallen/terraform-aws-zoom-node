variable "node_records" {
  type = map(object({
    workload_type                        = string
    node_number                          = number
    node_name                            = string
    fqdn                                 = string
    image_id                             = string
    instance_type                        = string
    root_volume_gb                       = number
    purchase_option                      = string
    source_dest_check                    = bool
    metadata_http_put_response_hop_limit = number
    security_profile                     = string
    iam_profile_key                      = string
    security_group_ids                   = list(string)
    iam_instance_profile_name            = string
  }))
}
variable "node_subnet_ids" { type = map(string) }
variable "node_private_ips" { type = map(list(string)) }
variable "node_user_data" {
  type      = map(string)
  sensitive = true
}
variable "node_eip_records" {
  type = map(object({
    node_key   = string
    eip_index  = number
    private_ip = string
    node_name  = string
    workload   = string
  }))
}
variable "security_group_configs" {
  type = map(object({ prefix = string, advanced = bool }))
}
variable "ingress_rule_records" {
  type = map(object({
    security_group_key = string
    description        = string
    protocol           = string
    from_port          = number
    to_port            = number
    cidr               = string
  }))
}
variable "egress_rule_records" {
  type = map(object({
    security_group_key = string
    description        = string
    protocol           = string
    from_port          = number
    to_port            = number
    cidr               = string
  }))
}
variable "iam_instance_profile_names" { type = map(string) }
variable "vpc_id" { type = string }
variable "key_name" {
  type    = string
  default = null
}
variable "root_volume_encrypted" { type = bool }
variable "root_volume_kms_key_id" {
  type    = string
  default = null
}
variable "cloudwatch_log_retention_days" { type = number }
variable "cloudwatch_log_kms_key_id" {
  type    = string
  default = null
}
variable "instance_tags" { type = map(string) }
variable "environment_name" { type = string }
variable "common_tags" { type = map(string) }
