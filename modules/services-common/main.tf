locals {
  common_tags = {
    BraintrustDeploymentName = var.deployment_name
  }
}

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}
