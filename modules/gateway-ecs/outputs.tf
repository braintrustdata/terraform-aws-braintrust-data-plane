output "gateway_url" {
  description = "Private gateway URL. Callers wait for the ECS service to reach steady state."
  value       = var.gateway_url
  depends_on  = [aws_ecs_service.gateway]
}

output "service_name" {
  description = "Name of the ECS gateway service"
  value       = aws_ecs_service.gateway.name
}

output "task_security_group_id" {
  description = "Security group ID attached to gateway ECS tasks"
  value       = aws_security_group.task.id
}

output "cloudwatch_log_groups" {
  description = "Names of the cloudwatch log groups created for the ECS gateway."
  value = {
    service = aws_cloudwatch_log_group.service.name
  }
}
