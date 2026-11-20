resource "aws_cloudwatch_log_group" "service" {
  name              = "/ecs/${var.deployment_name}/gateway"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = merge({
    Name = "${var.deployment_name}-gateway-logs"
  }, local.common_tags)
}
