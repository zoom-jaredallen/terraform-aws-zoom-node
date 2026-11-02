variable "aws_region" {
  description = "AWS region in which to create the example deployment."
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

variable "registration_code" {
  description = "Fresh Zoom Node registration code used by newly created nodes."
  type        = string
  sensitive   = true
}

variable "prod_ami_id" {
  description = "Customer-accessible production Zoom Node AMI in aws_region."
  type        = string
}
