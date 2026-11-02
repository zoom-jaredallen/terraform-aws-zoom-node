module "zoom_node" {
  source = "git::https://github.com/zoom-jaredallen/terraform-aws-zoom-node.git?ref=v0.4.0"

  environment_name         = local.environment
  domain_name              = "lab.zoomdemos.com"
  deployment_mode          = "public_cloud"
  network_mode             = "create_new"
  availability_zone_config = "single_az"
  registration_code        = var.registration_code
  node_password            = var.node_password

  source_cidrs = {
    remote_management_1 = local.management_cidrs
    internal_traffic    = local.internal_cidrs
  }

  explicit_nodes = {
    for node_name, node in local.nodes : node_name => {
      node_name                            = node_name
      fqdn                                 = node_name
      role                                 = "zoom_node"
      instance_type                        = local.instance_type
      image_id                             = local.image_id
      root_volume_gb                       = local.root_volume_gb
      private_ips                          = [node.private_ip]
      elastic_ips_per_node                 = 1
      subnet_tier                          = "public"
      subnet_index                         = 0
      purchase_option                      = "on_demand"
      source_dest_check                    = true
      metadata_http_put_response_hop_limit = 3
      security_group_ids                   = [aws_security_group.zoom_node.id]
    }
  }

  aws = {
    vpc_cidr            = local.vpc_cidr
    public_subnet_cidrs = [local.subnet_cidr]
    availability_zones  = [local.availability_zone]
  }
}
