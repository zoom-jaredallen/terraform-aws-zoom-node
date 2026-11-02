locals {
  common_tags = {
    Application = "Zoom-Node"
    Environment = var.environment_name
    ManagedBy   = "Terraform"
    Workload    = "AiServices"
  }
}

resource "aws_security_group" "ai_services" {
  name_prefix = "${var.node_name}-"
  description = "Zoom Node AI Services security group"
  vpc_id      = var.vpc_id

  ingress {
    description = "remote management TCP/8443"
    protocol    = "tcp"
    from_port   = 8443
    to_port     = 8443
    cidr_blocks = [var.management_cidr]
  }

  ingress {
    description = "kubernetes and internal node communications"
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = [var.kubernetes_cidr]
  }

  egress {
    description = "all outbound"
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name         = "${var.node_name}-sg"
    ZoomNodeName = var.node_name
  })
}
