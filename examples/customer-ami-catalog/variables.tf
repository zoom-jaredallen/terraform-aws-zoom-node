variable "aws_region" {
  description = "AWS region containing the customer-accessible Zoom Node AMIs."
  type        = string
  default     = "us-west-2"
}

variable "aws_max_retries" {
  description = "Maximum AWS provider API retries."
  type        = number
  default     = 5

  validation {
    condition     = var.aws_max_retries >= 0 && floor(var.aws_max_retries) == var.aws_max_retries
    error_message = "aws_max_retries must be a non-negative integer."
  }
}

variable "aws_retry_mode" {
  description = "AWS provider retry mode."
  type        = string
  default     = "standard"

  validation {
    condition     = contains(["standard", "adaptive"], var.aws_retry_mode)
    error_message = "aws_retry_mode must be standard or adaptive."
  }
}

variable "availability_zone" {
  description = "Availability Zone for the example node."
  type        = string
  default     = "us-west-2a"
}

variable "prod_ami_id" {
  description = "Customer-accessible production Zoom Node AMI in aws_region."
  type        = string
}

variable "dev_ami_id" {
  description = "Optional customer-accessible development Zoom Node AMI in aws_region."
  type        = string
  default     = null
  nullable    = true
}

variable "image_channel" {
  description = "Zoom Node image channel selected by this deployment."
  type        = string
  default     = "prod"

  validation {
    condition     = contains(["prod", "dev"], var.image_channel)
    error_message = "image_channel must be prod or dev."
  }
}

variable "registration_code" {
  description = "Fresh Zoom Node registration code."
  type        = string
  sensitive   = true
}
