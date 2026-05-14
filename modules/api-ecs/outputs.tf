output "service_name" {
  description = "Name of the API ECS service."
  value       = aws_ecs_service.api_ecs.name
}

output "alb_arn" {
  description = "ARN of the private API ECS ALB."
  value       = aws_lb.api_ecs.arn
}

output "alb_dns_name" {
  description = "DNS name of the private API ECS ALB."
  value       = aws_lb.api_ecs.dns_name
}

output "alb_zone_id" {
  description = "Hosted zone ID of the private API ECS ALB."
  value       = aws_lb.api_ecs.zone_id
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

output "https_url" {
  description = "HTTPS URL for API ECS ALB when TLS is enabled."
  value       = local.enable_https ? "https://${local.preferred_domain_name}" : null
}

output "effective_url" {
  description = "Preferred URL for API ECS ALB."
  value       = local.enable_https ? "https://${local.preferred_domain_name}" : "http://${aws_lb.api_ecs.dns_name}"
}

output "tls_ready" {
  description = "Whether API ECS ALB HTTPS is enabled with usable certificate configuration."
  value       = local.enable_https
}

output "fqdn" {
  description = "Full DNS name configured for the API ECS ALB."
  value       = local.api_fqdn
}

output "acm_certificate_arn" {
  description = "ARN of the ACM certificate selected for the API ECS ALB HTTPS listener."
  value       = local.selected_certificate_arn
}

output "acm_certificate_domain_validation_options" {
  description = "DNS validation options for the managed API ECS ALB ACM certificate."
  value = var.create_acm_certificate ? {
    for dvo in aws_acm_certificate.alb[0].domain_validation_options : dvo.domain_name => {
      domain_name = dvo.domain_name
      name        = dvo.resource_record_name
      type        = dvo.resource_record_type
      record      = dvo.resource_record_value
    }
  } : {}
}

output "dns_record_fqdn" {
  description = "FQDN of the optional Route53 alias record for the API ECS ALB."
  value       = var.create_dns_record ? aws_route53_record.alb_alias[0].fqdn : null
}
