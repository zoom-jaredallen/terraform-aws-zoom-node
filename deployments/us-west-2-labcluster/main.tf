module "zoom_node" {
  source = "git::https://github.com/zoom-jaredallen/terraform-aws-zoom-node.git?ref=v0.4.0"

  environment_name         = "labcluster"
  domain_name              = "lab.zoomdemos.com"
  deployment_mode          = "public_cloud"
  network_mode             = "create_new"
  availability_zone_config = "single_az"
  registration_code        = var.registration_code
  generate_node_password   = true

  image_ids = {
    prod = local.effective_prod_ami_id != "" ? { (var.aws_region) = local.effective_prod_ami_id } : {}
    dev  = local.effective_dev_ami_id != "" ? { (var.aws_region) = local.effective_dev_ami_id } : {}
  }

  source_cidrs = {
    zoom_clients        = ["0.0.0.0/0"]
    remote_management_1 = var.management_cidrs
    internal_traffic    = ["10.20.0.0/16"]
  }

  node_groups = {
    meetings_hybrid = {
      count                                = 1
      role                                 = "meetings_hybrid"
      hostname_prefix                      = "zmh"
      instance_type                        = var.meetings_hybrid_instance_type
      image_channel                        = "prod"
      root_volume_gb                       = 200
      private_ips_per_node                 = 5
      elastic_ips_per_node                 = 5
      private_ip_start_offset              = 10
      subnet_tier                          = "public"
      purchase_option                      = "spot"
      source_dest_check                    = true
      metadata_http_put_response_hop_limit = 3
      security_profile                     = "meetings_hybrid"
      iam_profile_key                      = "meetings_hybrid"
    }
    kubernetes_master = {
      count                                = 1
      role                                 = "kubernetes_master"
      hostname_prefix                      = "k8s-master"
      instance_type                        = var.kubernetes_master_instance_type
      image_channel                        = "dev"
      root_volume_gb                       = 500
      private_ips_per_node                 = 1
      elastic_ips_per_node                 = 1
      private_ip_start_offset              = 20
      subnet_tier                          = "public"
      purchase_option                      = "spot"
      source_dest_check                    = false
      metadata_http_put_response_hop_limit = 3
      security_profile                     = "kubernetes_master"
      iam_profile_key                      = "kubernetes"
    }
    kubernetes_workers = {
      count                                = 5
      role                                 = "kubernetes_worker"
      hostname_prefix                      = "k8s-worker"
      instance_type                        = var.kubernetes_worker_instance_type
      image_channel                        = "prod"
      root_volume_gb                       = 200
      private_ips_per_node                 = 1
      elastic_ips_per_node                 = 0
      private_ip_start_offset              = 30
      subnet_tier                          = "private"
      purchase_option                      = "spot"
      source_dest_check                    = true
      metadata_http_put_response_hop_limit = 3
      security_profile                     = "kubernetes_worker"
      iam_profile_key                      = "kubernetes"
    }
    ai_services = {
      count                                = 1
      role                                 = "ai_services"
      hostname_prefix                      = "ai"
      instance_type                        = var.ai_services_instance_type
      image_channel                        = "prod"
      root_volume_gb                       = 500
      private_ips_per_node                 = 1
      elastic_ips_per_node                 = 0
      private_ip_start_offset              = 100
      subnet_tier                          = "private"
      subnet_index                         = 1
      purchase_option                      = "on_demand"
      source_dest_check                    = true
      metadata_http_put_response_hop_limit = 3
      security_profile                     = "kubernetes_worker"
      iam_profile_key                      = "kubernetes"
    }
  }

  aws = {
    vpc_cidr             = "10.20.0.0/16"
    public_subnet_cidrs  = ["10.20.0.0/24"]
    private_subnet_cidrs = ["10.20.1.0/24", "10.20.2.0/24"]
    availability_zones   = [var.availability_zone, var.ai_services_availability_zone]
    create_nat_gateway   = true
    instance_tags = {
      PatchGroup  = "Linux"
      appliance   = "true"
      cost_center = "solution_engineering"
    }
    s3_bucket_access = {
      kubernetes = {
        bucket_name      = var.s3_bucket_name
        mode             = "create_new"
        iam_profile_keys = ["kubernetes"]
        actions          = ["s3:*"]
      }
    }
  }

  tags = {
    Environment = "Lab"
  }
}
