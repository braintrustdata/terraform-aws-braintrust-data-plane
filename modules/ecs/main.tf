locals {
  common_tags = merge({
    BraintrustDeploymentName = var.deployment_name
  }, var.custom_tags)
}

resource "aws_ecs_cluster" "this" {
  name = var.deployment_name
  setting {
    name  = "containerInsights"
    value = var.enable_container_insights ? "enabled" : "disabled"
  }

  tags = merge({
    Name = var.deployment_name
  }, local.common_tags)
}
