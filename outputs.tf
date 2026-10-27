output "vpc_id" {
  description = "VPC used for the Zoom Node deployment."
  value       = local.effective_vpc_id
}

output "subnet_ids" {
  description = "Subnets used for Zoom Node ENIs."
  value       = local.effective_subnet_ids
}

output "public_subnet_ids" {
  description = "Public subnet IDs used by advanced node groups."
  value       = local.effective_public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private subnet IDs used by advanced node groups."
  value       = local.effective_private_subnet_ids
}

output "nat_gateway_id" {
  description = "NAT Gateway ID when managed NAT egress is enabled."
  value       = module.network.nat_gateway_id
}

output "nat_gateway_public_ip" {
  description = "NAT Gateway Elastic IP when managed NAT egress is enabled."
  value       = module.network.nat_gateway_public_ip
}

output "workload_node_counts" {
  description = "Calculated node count per enabled workload."
  value = {
    for workload_type, workload in local.enabled_workloads : workload_type => workload.node_count
  }
}

output "security_group_ids" {
  description = "Security group ID per enabled workload."
  value       = module.node.security_group_ids
}

output "node_names" {
  description = "Zoom Node names by node key."
  value = {
    for node_key, node in local.node_records : node_key => node.node_name
  }
}

output "instance_ids" {
  description = "EC2 instance IDs by stable node key."
  value       = module.node.instance_ids
}

output "node_fqdns" {
  description = "Zoom Node FQDNs by node key."
  value = {
    for node_key, node in local.node_records : node_key => node.fqdn
  }
}

output "node_private_ips" {
  description = "Private IPv4 addresses by node key."
  value       = local.node_private_ips
}

output "node_public_ips" {
  description = "Elastic public IPv4 addresses by node key."
  value       = module.node.node_public_ips
}

output "node_purchase_options" {
  description = "EC2 purchase option used by each Zoom Node."
  value = {
    for node_key, node in local.node_records : node_key => node.purchase_option
  }
}

output "node_roles" {
  description = "Role assigned to each normalized node."
  value = {
    for node_key, node in local.node_records : node_key => node.role
  }
}

output "generated_node_password" {
  description = "Generated Zoom Node administrator password when generate_node_password is true; otherwise null."
  value       = var.generate_node_password ? random_password.node[0].result : null
  sensitive   = true
}

output "iam_instance_profile_names" {
  description = "IAM instance profile name per workload or advanced profile key."
  value       = module.storage_access.iam_instance_profile_names
}

output "s3_bucket_names" {
  description = "S3 bucket names configured for advanced IAM profiles."
  value = {
    for access_key, access in var.aws.s3_bucket_access : access_key => access.bucket_name
  }
}

output "hybrid_recording_s3_bucket_name" {
  description = "Deprecated compatibility output. Use s3_bucket_names[\"hybrid_recording\"]."
  value       = local.generic_hybrid_recording_s3_configured ? var.aws.s3_bucket_access["hybrid_recording"].bucket_name : var.hybrid_recording_s3_bucket_name
}
