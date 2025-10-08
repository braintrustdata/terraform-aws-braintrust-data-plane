locals {
  common_tags = {
    BraintrustDeploymentName = var.deployment_name
  }
}

data "aws_region" "current" {}
