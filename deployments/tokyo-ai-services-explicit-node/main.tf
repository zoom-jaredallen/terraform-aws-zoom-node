module "zoom_node" {
  source = "git::https://github.com/zoom-jaredallen/terraform-aws-zoom-node.git?ref=v0.4.0"

  environment_name         = var.environment_name
  domain_name              = "lab.zoomdemos.com"
  deployment_mode          = "public_cloud"
  network_mode             = "use_existing"
  availability_zone_config = "single_az"
  registration_code        = var.registration_code
  node_password            = var.node_password

  source_cidrs = {
    remote_management_1 = [var.management_cidr]
    internal_traffic    = [var.kubernetes_cidr]
  }

  explicit_nodes = {
    (var.node_name) = {
      node_name                            = var.node_name
      fqdn                                 = var.node_name
      role                                 = "ai_services"
      instance_type                        = var.instance_type
      image_id                             = var.image_id
      root_volume_gb                       = var.root_volume_gb
      private_ips                          = [var.private_ip]
      elastic_ips_per_node                 = 0
      subnet_tier                          = "public"
      subnet_index                         = 0
      purchase_option                      = "on_demand"
      source_dest_check                    = true
      metadata_http_put_response_hop_limit = 3
      security_group_ids                   = [aws_security_group.ai_services.id]
    }
    (var.additional_node_name) = {
      node_name                            = var.additional_node_name
      fqdn                                 = var.additional_node_name
      role                                 = "ai_services"
      instance_type                        = var.additional_instance_type
      image_id                             = var.image_id
      root_volume_gb                       = var.root_volume_gb
      private_ips                          = [var.additional_private_ip]
      elastic_ips_per_node                 = 0
      subnet_tier                          = "public"
      subnet_index                         = 0
      purchase_option                      = "on_demand"
      source_dest_check                    = true
      metadata_http_put_response_hop_limit = 3
      security_group_ids                   = [aws_security_group.ai_services.id]
    }
  }

  aws = {
    existing_vpc_id     = var.vpc_id
    existing_subnet_ids = [var.subnet_id]
  }
}
