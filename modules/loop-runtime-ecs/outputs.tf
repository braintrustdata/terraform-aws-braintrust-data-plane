output "service_name" {
  description = "Name of the ECS Loop runtime service"
  value       = aws_ecs_service.loop_runtime.name
}

output "task_security_group_id" {
  description = "Security group ID attached to Loop runtime ECS tasks"
  value       = aws_security_group.task.id
}

output "task_role_arn" {
  description = "ARN of the Loop runtime ECS task role"
  value       = aws_iam_role.task.arn
}
