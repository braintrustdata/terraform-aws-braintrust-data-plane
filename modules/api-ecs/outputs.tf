output "service_name" {
  description = "Name of the ECS API-ECS service"
  value       = aws_ecs_service.api_ecs.name
}

output "alb_arn" {
  description = "ARN of the private API-ECS ALB"
  value       = aws_lb.api_ecs.arn
}

output "alb_dns_name" {
  description = "DNS name of the private API-ECS ALB"
  value       = aws_lb.api_ecs.dns_name
}

output "target_group_arn" {
  description = "ARN of the API-ECS ALB target group"
  value       = aws_lb_target_group.api_ecs.arn
}

output "task_security_group_id" {
  description = "Security group ID attached to API-ECS tasks"
  value       = aws_security_group.task.id
}

output "http_url" {
  description = "Internal HTTP URL for API-ECS ALB"
  value       = "http://${aws_lb.api_ecs.dns_name}"
}

output "https_url" {
  description = "Internal HTTPS URL for API-ECS ALB when TLS is enabled"
  value       = local.enable_https ? "https://${aws_lb.api_ecs.dns_name}" : null
}

output "effective_url" {
  description = "Preferred internal URL for API-ECS ALB"
  value       = local.enable_https ? "https://${aws_lb.api_ecs.dns_name}" : "http://${aws_lb.api_ecs.dns_name}"
}

output "tls_ready" {
  description = "Whether API-ECS ALB HTTPS is effectively enabled with usable certificate configuration."
  value       = local.enable_https
}

output "cloudfront_origin_protocol_policy" {
  description = "Recommended CloudFront origin protocol policy for the API-ECS ALB."
  value       = local.enable_https ? "https-only" : "http-only"
}

output "cloudfront_origin_domain_name" {
  description = "Domain name for CloudFront to use as the origin. When HTTPS is enabled, returns the certificate domain so SNI matches the ALB certificate."
  value       = local.enable_https && local.certificate_domain_name != null ? local.certificate_domain_name : aws_lb.api_ecs.dns_name
}
