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

output "target_group_arn" {
  description = "ARN of the API ECS ALB target group."
  value       = aws_lb_target_group.api_ecs.arn
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

output "dns_record_fqdn" {
  description = "FQDN of the optional Route53 alias record for the API ECS ALB."
  value       = var.create_dns_record ? aws_route53_record.alb_alias[0].fqdn : null
}

output "cloudfront_origin_protocol_policy" {
  description = "CloudFront origin protocol policy for the API ECS ALB."
  value       = local.enable_https ? "https-only" : "http-only"
}

output "cloudfront_origin_domain_name" {
  description = "Domain name for CloudFront to use as the origin."
  value       = local.enable_https && local.api_fqdn != null ? local.api_fqdn : aws_lb.api_ecs.dns_name
}
