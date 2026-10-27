variable "aws_region" {
  description = "AWS region containing the existing VPC and subnets."
  type        = string
  default     = "us-west-2"
}

variable "registration_code" {
  description = "Fresh Zoom Node registration code used by newly created nodes."
  type        = string
  sensitive   = true
}

variable "existing_vpc_id" {
  description = "ID of the existing VPC in which to deploy Zoom Nodes."
  type        = string
}

variable "existing_subnet_ids" {
  description = "Existing subnet IDs used for Zoom Node network interfaces."
  type        = list(string)
}
