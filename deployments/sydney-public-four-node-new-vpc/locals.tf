locals {
  environment       = "sydney-public"
  availability_zone = "ap-southeast-2a"
  vpc_cidr          = "10.20.0.0/16"
  subnet_cidr       = "10.20.101.0/24"
  adopted_vpc_id    = "vpc-081b71423786fc0d2"
  image_id          = "ami-06fa0d385e7d8a382"
  instance_type     = "t3.large"
  root_volume_gb    = 500

  management_cidrs = ["38.99.100.7/32", "180.150.42.155/32"]
  internal_cidrs   = ["10.0.0.0/8"]

  nodes = {
    syd01node1-ap-southeast-2a = {
      private_ip      = "10.20.101.10"
      instance_id     = "i-0558701eab94b0d30"
      eni_id          = "eni-05160d655b886e654"
      eip_allocation  = "eipalloc-0ec16e87303bc4394"
      eip_association = "eipassoc-08fcdd4187157dc2c"
    }
    syd01node2-ap-southeast-2a = {
      private_ip      = "10.20.101.20"
      instance_id     = "i-0fc581b0191927654"
      eni_id          = "eni-0e0e8e5c779ec5a37"
      eip_allocation  = "eipalloc-0d7af3e0a19890818"
      eip_association = "eipassoc-057de5ed4fccb2337"
    }
    syd01node3-ap-southeast-2a = {
      private_ip      = "10.20.101.30"
      instance_id     = "i-0268da7278ea573fb"
      eni_id          = "eni-079c5bf7553e18652"
      eip_allocation  = "eipalloc-057f45935bc4e1965"
      eip_association = "eipassoc-0c0ec554d36f3d74f"
    }
    syd01node4-ap-southeast-2a = {
      private_ip      = "10.20.101.40"
      instance_id     = "i-0a970d6f8f90f86c4"
      eni_id          = "eni-09b2bc4e38b64fdc6"
      eip_allocation  = "eipalloc-08118a9a88354431c"
      eip_association = "eipassoc-0933eb81b6cb9b0f6"
    }
  }

  common_tags = {
    Application = "Zoom-Node"
    Environment = "SydneyPublic"
    ManagedBy   = "Terraform"
  }
}
