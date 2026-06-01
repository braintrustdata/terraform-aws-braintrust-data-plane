output "service_name" {
  description = "Name of the API ECS service."
  value       = aws_ecs_service.api_ecs.name
}

output "alb_arn" {
  description = "ARN of the API ECS ALB."
  value       = aws_lb.api_ecs.arn
}

output "alb_dns_name" {
  description = "DNS name of the API ECS ALB."
  value       = aws_lb.api_ecs.dns_name
}

output "alb_zone_id" {
  description = "Hosted zone ID of the API ECS ALB."
  value       = aws_lb.api_ecs.zone_id
}

output "target_group_arn" {
  description = "ARN of the API ECS ALB target group."
  value       = aws_lb_target_group.api_ecs.arn
}

output "alb_security_group_id" {
  description = "Security group ID attached to the API ECS ALB."
  value       = aws_security_group.alb.id
}

output "task_security_group_id" {
  description = "Security group ID attached to API ECS tasks."
  value       = var.task_security_group_id
}

output "https_url" {
  description = "HTTPS URL for API ECS ALB."
  value       = local.https_url
}

output "client_url" {
  description = "URL clients should use for the API ECS ALB."
  value       = local.https_url
}

output "fqdn" {
  description = "Full DNS name configured for the API ECS ALB."
  value       = var.fqdn
}

output "acm_certificate_arn" {
  description = "ARN of the ACM certificate selected for the API ECS ALB HTTPS listener."
  value       = var.acm_certificate_arn
}

output "url_ssm_parameter_name" {
  description = "Name of the SSM parameter containing the API ECS URL."
  value       = aws_ssm_parameter.api_url.name
}
