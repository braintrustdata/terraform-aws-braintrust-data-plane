output "alb_arn" {
  description = "ARN of the API ALB."
  value       = aws_lb.api_ecs.arn
}

output "alb_arn_suffix" {
  description = "ARN suffix of the API ALB for CloudWatch dimensions."
  value       = aws_lb.api_ecs.arn_suffix
}

output "alb_dns_name" {
  description = "DNS name of the API ALB."
  value       = aws_lb.api_ecs.dns_name
}

output "alb_https_enabled" {
  description = "Whether the API ALB serves HTTPS."
  value       = local.https_enabled
}

output "alb_domain" {
  description = "Domain used for the API ALB origin."
  value       = local.https_enabled ? var.custom_domain : aws_lb.api_ecs.dns_name
}

output "alb_security_group_id" {
  description = "Security group ID attached to the API ALB."
  value       = aws_security_group.alb.id
}

output "http_url" {
  description = "URL of the API ALB."
  value       = local.api_ecs_url
}

output "target_group_arn" {
  description = "ARN of the primary braintrust-api target group."
  value       = aws_lb_target_group.braintrust_api.arn
}

output "target_group_arns" {
  description = "ARNs of all API target groups."
  value = {
    braintrust_api            = aws_lb_target_group.braintrust_api.arn
    braintrust_api_ingest     = aws_lb_target_group.braintrust_api_ingest.arn
    braintrust_api_background = aws_lb_target_group.braintrust_api_background.arn
  }
}

output "target_group_arn_suffixes" {
  description = "ARN suffixes of all API target groups for CloudWatch dimensions."
  value = {
    braintrust_api            = aws_lb_target_group.braintrust_api.arn_suffix
    braintrust_api_ingest     = aws_lb_target_group.braintrust_api_ingest.arn_suffix
    braintrust_api_background = aws_lb_target_group.braintrust_api_background.arn_suffix
  }
}

output "http_listener_arn" {
  description = "ARN of the API ALB listener."
  value       = aws_lb_listener.api_ecs_http.arn
}

output "path_listener_rule_arns" {
  description = "ARNs of the API ALB path-routing rules."
  value       = { for key, rule in aws_lb_listener_rule.alb_path_routes : key => rule.arn }
}
