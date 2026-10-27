variable "aws_region" {
  description = "AWS region in which to create the example deployment."
  type        = string
  default     = "us-west-2"
}

variable "registration_code" {
  description = "Fresh Zoom Node registration code used by newly created nodes."
  type        = string
  sensitive   = true
}
