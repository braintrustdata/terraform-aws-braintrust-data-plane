output "service_name" {
  description = "Name of the API ECS service."
  value       = aws_ecs_service.api_ecs.name
}

output "alb_arn" {
  description = "ARN of the private API ECS ALB."
  value       = aws_lb.api_ecs.arn
}

output "target_group_arn" {
  description = "ARN of the API ECS ALB target group."
  value       = aws_lb_target_group.api_ecs.arn
}

output "alb_security_group_id" {
  description = "Security group ID attached to the private API ECS ALB."
  value       = aws_security_group.alb.id
}

output "task_security_group_id" {
  description = "Security group ID attached to API ECS tasks."
  value       = var.task_security_group_id
}

output "http_url" {
  description = "HTTP URL for API ECS ALB."
  value       = "http://${aws_lb.api_ecs.dns_name}"
}

output "effective_url" {
  description = "Preferred URL for API ECS ALB."
  value       = "http://${aws_lb.api_ecs.dns_name}"
}
