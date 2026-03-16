locals {
  common_tags = merge({
    BraintrustDeploymentName = var.deployment_name
  }, var.custom_tags)
}

resource "aws_ecs_cluster" "dataplane" {
  name = "${var.deployment_name}-dataplane"

  configuration {
    execute_command_configuration {
      kms_key_id = var.kms_key_arn
      logging    = "DEFAULT"
    }

    managed_storage_configuration {
      kms_key_id                           = var.kms_key_arn
      fargate_ephemeral_storage_kms_key_id = var.kms_key_arn
    }
  }

  setting {
    name  = "containerInsights"
    value = var.container_insights
  }

  tags = merge({
    Name = var.deployment_name
  }, local.common_tags)
}
