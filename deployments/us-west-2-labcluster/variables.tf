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
  default = "us-west-2"
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
  default     = "us-west-2a"
  description = "Single Availability Zone used by the public and private lab subnets."
}

variable "ai_services_availability_zone" {
  type        = string
  default     = "us-west-2b"
  description = "Availability Zone for the dedicated AI Services private subnet."
}

variable "management_cidrs" {
  type        = list(string)
  default     = ["180.150.42.155/32"]
  description = "Trusted source CIDRs allowed to manage public ingress nodes."
}

variable "s3_bucket_name" {
  type        = string
  default     = "zoomnode-labcluster-s3"
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
  description = "EC2 instance type for the Kubernetes master node."
}

variable "kubernetes_worker_instance_type" {
  type        = string
  default     = "c8i.4xlarge"
  description = "EC2 instance type for the Kubernetes worker nodes."
}

variable "ai_services_instance_type" {
  type        = string
  default     = "g5.12xlarge"
  description = "EC2 instance type for the On-Demand AI Services nodes with four NVIDIA A10G GPUs."
}

variable "registration_code" {
  type        = string
  sensitive   = true
  description = "Fresh 16-character Zoom Node registration code supplied at plan or apply time."
}
