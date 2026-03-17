output "service_name" {
  description = "Name of the ECS gateway service"
  value       = aws_ecs_service.gateway.name
}

output "alb_arn" {
  description = "ARN of the private gateway ALB"
  value       = aws_lb.gateway.arn
}

output "alb_dns_name" {
  description = "DNS name of the private gateway ALB"
  value       = aws_lb.gateway.dns_name
}

output "target_group_arn" {
  description = "ARN of the gateway ALB target group"
  value       = aws_lb_target_group.gateway.arn
}

output "task_security_group_id" {
  description = "Security group ID attached to gateway ECS tasks"
  value       = aws_security_group.task.id
}
