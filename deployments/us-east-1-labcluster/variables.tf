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

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "aws_account_id" {
  type        = string
  default     = "626657815993"
  description = "AWS account allowed to manage this deployment. The provider rejects all other authenticated accounts."

  validation {
    condition     = can(regex("^[0-9]{12}$", var.aws_account_id))
    error_message = "aws_account_id must be a 12-digit AWS account ID."
  }
}

variable "prod_ami_id" {
  type        = string
  default     = null
  nullable    = true
  description = "Optional production Zoom Node AMI override. When omitted, the deployment catalog is used for aws_region."

  validation {
    condition     = var.prod_ami_id == null ? true : can(regex("^ami-([0-9a-f]{8}|[0-9a-f]{17})$", trimspace(var.prod_ami_id)))
    error_message = "prod_ami_id must be null or a valid AMI ID."
  }
}

variable "dev_ami_id" {
  type        = string
  default     = null
  nullable    = true
  description = "Optional development Zoom Node AMI override. When omitted, the deployment catalog is used for aws_region."

  validation {
    condition     = var.dev_ami_id == null ? true : can(regex("^ami-([0-9a-f]{8}|[0-9a-f]{17})$", trimspace(var.dev_ami_id)))
    error_message = "dev_ami_id must be null or a valid AMI ID."
  }
}

variable "availability_zone" {
  type        = string
  default     = "us-east-1a"
  description = "Availability Zone used by Meetings Hybrid, Kubernetes masters, and CPU workers."
}

variable "ai_services_availability_zone" {
  type        = string
  default     = "us-east-1b"
  description = "Availability Zone used by the dedicated AI Services private subnet."
}

variable "management_cidrs" {
  type        = list(string)
  default     = ["180.150.42.155/32"]
  description = "Trusted source CIDRs allowed to manage public ingress nodes."
}

variable "s3_bucket_name" {
  type        = string
  default     = "zoomnode-use1-labcluster-626657815993"
  description = "Globally unique S3 bucket name shared by the Kubernetes nodes."
}

variable "meetings_hybrid_instance_type" {
  type        = string
  default     = "c8i-flex.2xlarge"
  description = "EC2 instance type for the Meetings Hybrid node."
}

variable "kubernetes_master_instance_type" {
  type        = string
  default     = "c7i-flex.xlarge"
  description = "EC2 instance type for each Kubernetes master node."
}

variable "kubernetes_worker_instance_type" {
  type        = string
  default     = "c8i.4xlarge"
  description = "EC2 instance type for each Kubernetes worker node."
}

variable "ai_services_instance_type" {
  type        = string
  default     = "g6.12xlarge"
  description = "EC2 instance type for the On-Demand AI Services node with four NVIDIA L4 GPUs."
}

variable "ai_services_ami_id" {
  type        = string
  default     = null
  nullable    = true
  description = "Optional AI Services AMI override. When null, AI Services uses the regional production image catalog entry."

  validation {
    condition     = var.ai_services_ami_id == null ? true : can(regex("^ami-([0-9a-f]{8}|[0-9a-f]{17})$", trimspace(var.ai_services_ami_id)))
    error_message = "ai_services_ami_id must be null or a valid AMI ID."
  }
}

variable "registration_code" {
  type        = string
  sensitive   = true
  description = "Fresh 16-character Zoom Node registration code supplied at plan or apply time."
}
