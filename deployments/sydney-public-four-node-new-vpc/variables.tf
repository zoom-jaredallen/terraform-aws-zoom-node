variable "aws_max_retries" {
  type    = number
  default = 5
  validation {
    condition     = var.aws_max_retries >= 0 && floor(var.aws_max_retries) == var.aws_max_retries
    error_message = "aws_max_retries must be a non-negative integer."
  }
}

variable "aws_retry_mode" {
  type    = string
  default = "standard"
  validation {
    condition     = contains(["standard", "adaptive"], var.aws_retry_mode)
    error_message = "aws_retry_mode must be standard or adaptive."
  }
}

variable "registration_code" {
  type        = string
  sensitive   = true
  description = "Fresh Zoom Node registration code."

  validation {
    condition     = can(regex("^[A-Za-z0-9]{16}$", var.registration_code))
    error_message = "registration_code must be exactly 16 alphanumeric characters."
  }
}

variable "node_password" {
  type        = string
  sensitive   = true
  description = "Initial Zoom Node local administrator password."

  validation {
    condition = (
      length(var.node_password) >= 8 &&
      length(var.node_password) <= 16 &&
      can(regex("[A-Z]", var.node_password)) &&
      can(regex("[a-z]", var.node_password)) &&
      can(regex("[0-9]", var.node_password)) &&
      can(regex("[!.@%#*_%~?]", var.node_password)) &&
      can(regex("^[A-Za-z0-9!.@%#*_%~?]+$", var.node_password))
    )
    error_message = "node_password must be 8-16 characters and include uppercase, lowercase, number, and allowed symbol."
  }
}
