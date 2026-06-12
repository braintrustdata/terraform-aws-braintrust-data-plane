output "service_name" {
  description = "Name of the ECS gateway service"
  value       = aws_ecs_service.gateway.name
}

output "task_security_group_id" {
  description = "Security group ID attached to gateway ECS tasks"
  value       = aws_security_group.task.id
}
