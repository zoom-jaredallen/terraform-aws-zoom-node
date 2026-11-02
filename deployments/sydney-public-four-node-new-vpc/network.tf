resource "aws_security_group" "zoom_node" {
  name_prefix = "sydney-public-zoom-node-"
  description = "Zoom Node public deployment security group"
  vpc_id      = local.adopted_vpc_id

  ingress {
    description = "remote management TCP/8443"
    protocol    = "tcp"
    from_port   = 8443
    to_port     = 8443
    cidr_blocks = local.management_cidrs
  }

  ingress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = local.internal_cidrs
  }

  egress {
    description = "all outbound"
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, { Name = "sydney-public-zoom-node-sg" })
}
