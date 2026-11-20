output "service_name" {
  description = "Name of the primary braintrust-api ECS service."
  value       = aws_ecs_service.braintrust_api.name
}

output "service_names" {
  description = "Names of all API ECS services."
  value = {
    braintrust_api            = aws_ecs_service.braintrust_api.name
    braintrust_api_ingest     = aws_ecs_service.braintrust_api_ingest.name
    braintrust_api_background = aws_ecs_service.braintrust_api_background.name
  }
}

output "monitoring_targets" {
  description = "API ECS service and target group identifiers keyed by stable role for monitoring integrations."
  value = {
    api-ecs = {
      alarm_group   = "api-ecs"
      service_name  = aws_ecs_service.braintrust_api.name
      tg_arn_suffix = aws_lb_target_group.braintrust_api.arn_suffix
    }
    api-ingest = {
      alarm_group   = "api-ecs"
      service_name  = aws_ecs_service.braintrust_api_ingest.name
      tg_arn_suffix = aws_lb_target_group.braintrust_api_ingest.arn_suffix
    }
    api-background = {
      alarm_group   = "api-ecs"
      service_name  = aws_ecs_service.braintrust_api_background.name
      tg_arn_suffix = aws_lb_target_group.braintrust_api_background.arn_suffix
    }
  }
}

output "alb_arn" {
  description = "ARN of the API ECS ALB."
  value       = aws_lb.api_ecs.arn
}

output "alb_arn_suffix" {
  description = "ARN suffix of the API ECS ALB for CloudWatch dimensions."
  value       = aws_lb.api_ecs.arn_suffix
}

output "alb_dns_name" {
  description = "DNS name of the API ECS ALB."
  value       = aws_lb.api_ecs.dns_name
}

output "alb_https_enabled" {
  description = "Whether a customer HTTPS listener is configured on the API ALB."
  value       = local.alb_https_enabled
}

output "alb_domain" {
  description = "AWS-assigned API ALB DNS name for the CloudFront HTTP origin."
  value       = aws_lb.api_ecs.dns_name
  depends_on = [
    aws_lb_listener_rule.alb_path_routes,
    aws_lb_listener_rule.alb_public_http_path_routes,
    aws_vpc_security_group_ingress_rule.alb_ingress_http_from_cloudfront,
    aws_vpc_security_group_ingress_rule.alb_ingress_http_from_cloudfront_http,
    aws_vpc_security_group_ingress_rule.alb_ingress_http_from_gateway,
  ]
}

output "target_group_arn" {
  description = "ARN of the braintrust-api ALB target group."
  value       = aws_lb_target_group.braintrust_api.arn
}

output "target_group_arn_suffix" {
  description = "ARN suffix of the braintrust-api ALB target group for CloudWatch dimensions."
  value       = aws_lb_target_group.braintrust_api.arn_suffix
}

output "target_group_arns" {
  description = "ARNs of all API ECS ALB target groups."
  value = {
    braintrust_api            = aws_lb_target_group.braintrust_api.arn
    braintrust_api_ingest     = aws_lb_target_group.braintrust_api_ingest.arn
    braintrust_api_background = aws_lb_target_group.braintrust_api_background.arn
  }
}

output "alb_security_group_id" {
  description = "Security group ID attached to the API ECS ALB."
  value       = aws_security_group.alb.id
}

output "task_security_group_id" {
  description = "Security group ID attached to API ECS tasks."
  value       = var.task_security_group_id
}

output "http_url" {
  description = "Internal API ECS URL for services. The separate-listener layout uses HTTP on the ALB DNS name."
  value       = local.api_ecs_url
  depends_on = [
    aws_lb_listener.api_ecs_http,
    aws_lb_listener.api_ecs_public_http,
    aws_lb_listener_rule.alb_path_routes,
    aws_lb_listener_rule.alb_public_http_path_routes,
    aws_vpc_security_group_ingress_rule.alb_ingress_http_from_public_services,
    aws_vpc_security_group_ingress_rule.alb_ingress_http_from_gateway,
    aws_vpc_security_group_ingress_rule.alb_ingress_from_gateway,
  ]
}

output "customer_https_url" {
  description = "Customer HTTPS URL after the listener and direct Gateway and Loop routes are ready. Null until direct routes are active."
  value       = local.customer_https_routes ? "https://${var.alb_custom_domain}" : null
  depends_on = [
    aws_lb_listener.api_ecs_http,
    aws_lb_listener.api_ecs_https,
    aws_lb_listener_rule.alb_path_routes,
    aws_lb_listener_rule.alb_customer_https_path_routes,
    aws_lb_listener_rule.private_gateway,
    aws_lb_listener_rule.private_loop_runtime,
    aws_security_group_rule.alb_ingress_http_from_authorized_security_groups,
    aws_security_group_rule.alb_ingress_http_from_authorized_cidr_blocks,
  ]
}

output "internal_url" {
  description = "Internal HTTP URL for service callbacks in private mode. Null in public mode."
  value       = local.internal_api_url
  depends_on = [
    aws_lb_listener.api_ecs_internal,
    aws_vpc_security_group_ingress_rule.alb_ingress_from_gateway,
    aws_lb_listener_rule.alb_internal_path_routes,
    aws_vpc_security_group_ingress_rule.alb_ingress_http_from_internal_security_groups,
  ]
}

output "quarantine_proxy_url" {
  description = "QUARANTINE_PROXY_URL on API ECS. Private mode uses QUARANTINE_API_URL through extra_env_vars."
  value       = local.quarantine_proxy_url
}

output "url_ssm_parameter_name" {
  description = "Name of the SSM parameter containing the API ECS URL."
  value       = aws_ssm_parameter.api_url.name
}

output "url_ssm_parameter_version" {
  description = "Version of the SSM parameter containing the API ECS URL. Increments whenever the URL changes (e.g. HTTP -> HTTPS), so consumers can pin to it and force a refresh."
  value       = aws_ssm_parameter.api_url.version
}

output "cloudwatch_log_groups" {
  description = "Names of the cloudwatch log groups created for ECS."
  value = {
    braintrust_api            = aws_cloudwatch_log_group.braintrust_api.name
    braintrust_api_ingest     = aws_cloudwatch_log_group.braintrust_api_ingest.name
    braintrust_api_background = aws_cloudwatch_log_group.braintrust_api_background.name
  }
}

output "private_gateway_target_group_arn" {
  description = "Target group for direct gateway access through the customer listener."
  value       = one(aws_lb_target_group.private_gateway[*].arn)
  depends_on  = [aws_lb_listener_rule.private_gateway]
}

output "private_loop_runtime_target_group_arn" {
  description = "Target group for direct Loop access through the customer listener."
  value       = one(aws_lb_target_group.private_loop_runtime[*].arn)
  depends_on  = [aws_lb_listener_rule.private_loop_runtime]
}

output "quarantine_alb_arn" {
  description = "This output returns the API ALB ARN after the internal listener and quarantine authorization exist."
  value       = aws_lb.api_ecs.arn
  depends_on = [
    aws_lb_listener.api_ecs_internal,
    aws_lb_listener_rule.alb_internal_path_routes,
    aws_lb_listener_rule.private_internal_gateway,
    aws_vpc_security_group_ingress_rule.alb_ingress_http_from_internal_security_groups,
  ]
}
