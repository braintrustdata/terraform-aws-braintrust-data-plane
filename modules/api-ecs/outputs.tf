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

output "task_security_group_id" {
  description = "Security group ID attached to API ECS tasks."
  value       = var.task_security_group_id
}

output "quarantine_proxy_url" {
  description = "QUARANTINE_PROXY_URL baked into API ECS."
  value       = var.quarantine_proxy_url
}
