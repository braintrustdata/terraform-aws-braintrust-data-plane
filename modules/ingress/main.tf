locals {
  common_tags = merge({
    BraintrustDeploymentName = var.deployment_name
  }, var.custom_tags)
}

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}
