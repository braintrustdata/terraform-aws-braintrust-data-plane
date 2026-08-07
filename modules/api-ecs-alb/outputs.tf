output "alb_arn" {
  description = "ARN of the API ECS ALB."
  value       = aws_lb.api_ecs.arn
}

output "alb_dns_name" {
  description = "DNS name of the API ECS ALB."
  value       = aws_lb.api_ecs.dns_name
}

output "alb_https_enabled" {
  description = "Whether the API ECS ALB serves HTTPS (a certificate and custom domain were provided)."
  value       = local.alb_https_enabled
}

output "alb_domain" {
  description = "Domain to use as the API ECS ALB origin: the custom domain when serving HTTPS (so the certificate validates), otherwise the ALB's AWS-assigned DNS name."
  value       = local.alb_https_enabled ? var.alb_custom_domain : aws_lb.api_ecs.dns_name
}

output "alb_security_group_id" {
  description = "Security group ID attached to the API ECS ALB."
  value       = aws_security_group.alb.id
}

output "target_group_arn" {
  description = "ARN of the braintrust-api ALB target group."
  value       = aws_lb_target_group.braintrust_api.arn
}

output "target_group_arns" {
  description = "ARNs of all API ECS ALB target groups."
  value = {
    braintrust_api            = aws_lb_target_group.braintrust_api.arn
    braintrust_api_ingest     = aws_lb_target_group.braintrust_api_ingest.arn
    braintrust_api_background = aws_lb_target_group.braintrust_api_background.arn
  }
}

output "http_url" {
  description = "URL for the API ECS ALB (https://<custom domain> when a certificate and custom domain are provided, otherwise http://<ALB DNS name>)."
  value       = local.api_ecs_url
}

output "url_ssm_parameter_name" {
  description = "Name of the SSM parameter containing the API ECS URL."
  value       = aws_ssm_parameter.api_url.name
}

output "url_ssm_parameter_version" {
  description = "Version of the SSM parameter containing the API ECS URL. Increments whenever the URL changes (e.g. HTTP -> HTTPS), so consumers can pin to it and force a refresh."
  value       = aws_ssm_parameter.api_url.version
}

output "listener_arn" {
  description = "ARN of the API ECS ALB listener. ECS services must wait for this before CreateService."
  value       = aws_lb_listener.api_ecs_http.arn
}

output "path_listener_rule_arns" {
  description = "ARNs of ALB path listener rules. Ingest/background ECS services must wait for these before CreateService."
  value       = [for rule in aws_lb_listener_rule.alb_path_routes : rule.arn]
}
