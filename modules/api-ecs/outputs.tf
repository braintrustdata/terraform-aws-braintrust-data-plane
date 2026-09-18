output "service_name" {
  description = "Name of the primary braintrust-api ECS service."
  value       = aws_ecs_service.braintrust_api.name
}

output "service_names" {
  description = "Names of all API ECS services."
  value = {
    braintrust_api            = aws_ecs_service.braintrust_api.name
    braintrust_api_ingest     = aws_ecs_service.braintrust_api_ingest.name
    braintrust_api_background = aws_ecs_service.braintrust_api_background.name
  }
}

output "monitoring_targets" {
  description = "API ECS service and target group identifiers keyed by stable role for monitoring integrations."
  value = {
    api-ecs = {
      alarm_group   = "api-ecs"
      service_name  = aws_ecs_service.braintrust_api.name
      tg_arn_suffix = var.target_group_arn_suffixes["braintrust_api"]
    }
    api-ingest = {
      alarm_group   = "api-ecs"
      service_name  = aws_ecs_service.braintrust_api_ingest.name
      tg_arn_suffix = var.target_group_arn_suffixes["braintrust_api_ingest"]
    }
    api-background = {
      alarm_group   = "api-ecs"
      service_name  = aws_ecs_service.braintrust_api_background.name
      tg_arn_suffix = var.target_group_arn_suffixes["braintrust_api_background"]
    }
  }
}

output "task_security_group_id" {
  description = "Security group ID attached to API ECS tasks."
  value       = var.task_security_group_id
}

output "quarantine_proxy_url" {
  description = "Effective QUARANTINE_PROXY_URL on API ECS when set; null when the env var is omitted."
  value       = local.quarantine_proxy_url
}

output "cloudwatch_log_groups" {
  description = "Names of the cloudwatch log groups created for ECS."
  value = {
    braintrust_api            = aws_cloudwatch_log_group.braintrust_api.name
    braintrust_api_ingest     = aws_cloudwatch_log_group.braintrust_api_ingest.name
    braintrust_api_background = aws_cloudwatch_log_group.braintrust_api_background.name
  }
}
