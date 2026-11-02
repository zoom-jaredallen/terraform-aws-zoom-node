provider "aws" {
  region      = "ap-southeast-2"
  max_retries = var.aws_max_retries
  retry_mode  = var.aws_retry_mode

  ignore_tags {
    keys = ["AttachedInstance", "Owner", "appliance", "team"]
  }
}
