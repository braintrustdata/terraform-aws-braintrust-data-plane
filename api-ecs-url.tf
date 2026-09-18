resource "aws_ssm_parameter" "api_ecs_url" {
  count = local.create_ecs_api ? 1 : 0

  name        = local.api_ecs_url_ssm_parameter_name
  type        = "String"
  value       = module.api_alb[0].http_url
  description = "API ECS URL for Brainstore"

  tags = merge({
    BraintrustDeploymentName = var.deployment_name
  }, local.all_custom_tags)
}
