locals {
  nodes = {
    sg01master1-ap-southeast-1a = { instance_type = "t3.xlarge", role = "kubernetes_master", source_dest_check = false, private_ip = "10.0.101.251" }
    sg01master2-ap-southeast-1a = { instance_type = "t3.xlarge", role = "kubernetes_master", source_dest_check = false, private_ip = "10.0.101.252" }
    sg01master3-ap-southeast-1a = { instance_type = "t3.xlarge", role = "kubernetes_master", source_dest_check = false, private_ip = "10.0.101.253" }
    sg01worker1-ap-southeast-1a = { instance_type = "m7i.2xlarge", role = "kubernetes_worker", source_dest_check = true, private_ip = "10.0.101.241" }
    sg01worker2-ap-southeast-1a = { instance_type = "m7i.2xlarge", role = "kubernetes_worker", source_dest_check = true, private_ip = "10.0.101.242" }
    sg01worker3-ap-southeast-1a = { instance_type = "m7i.2xlarge", role = "kubernetes_worker", source_dest_check = true, private_ip = "10.0.101.243" }
    sg01worker4-ap-southeast-1a = { instance_type = "m7i.2xlarge", role = "kubernetes_worker", source_dest_check = true, private_ip = "10.0.101.244" }
    sg01worker5-ap-southeast-1a = { instance_type = "m7i.2xlarge", role = "kubernetes_worker", source_dest_check = true, private_ip = "10.0.101.245" }
  }
}

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
    remote_management_1 = ["10.0.0.0/8"]
    internal_traffic    = ["10.0.0.0/8"]
  }

  explicit_nodes = {
    for node_name, node in local.nodes : node_name => {
      node_name                            = node_name
      fqdn                                 = node_name
      role                                 = node.role
      instance_type                        = node.instance_type
      image_id                             = var.image_id
      root_volume_gb                       = var.root_volume_gb
      private_ips                          = [node.private_ip]
      elastic_ips_per_node                 = 0
      subnet_tier                          = "public"
      subnet_index                         = 0
      purchase_option                      = "on_demand"
      source_dest_check                    = node.source_dest_check
      metadata_http_put_response_hop_limit = 3
      security_group_ids                   = [var.security_group_id]
      iam_instance_profile_name            = var.iam_instance_profile
    }
  }

  aws = {
    existing_vpc_id     = var.vpc_id
    existing_subnet_ids = [var.subnet_id]
  }
}
