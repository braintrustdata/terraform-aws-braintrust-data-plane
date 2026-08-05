output "gateway_alb_dns_name" {
  description = "Internal DNS name of the private gateway ALB"
  value       = aws_lb.gateway.dns_name
}

output "gateway_alb_arn" {
  description = "ARN of the private gateway ALB"
  value       = aws_lb.gateway.arn
}

output "gateway_alb_security_group_id" {
  description = "Security group ID attached to the private gateway ALB"
  value       = aws_security_group.gateway_alb.id
}

output "gateway_target_group_arn" {
  description = "ARN of the gateway ALB target group"
  value       = aws_lb_target_group.gateway.arn
}

output "gateway_http_listener_arn" {
  description = "ARN of the gateway ALB HTTP listener"
  value       = aws_lb_listener.gateway_http.arn
}

output "gateway_url" {
  description = "Private in-VPC gateway URL for GATEWAY_URL on api-ts services"
  value       = "http://${aws_lb.gateway.dns_name}"
}

output "gateway_cloudfront_vpc_origin_ingress_rule_id" {
  description = "Security group ingress rule allowing CloudFront VPC origins to reach the gateway ALB."
  value       = try(aws_vpc_security_group_ingress_rule.gateway_alb_from_cloudfront_vpc_origin[0].id, null)
}

output "gateway_alb_subnet_ids" {
  description = "Subnet IDs attached to the private gateway ALB."
  value       = local.gateway_alb_subnet_ids
}

output "alb_subnets_applied" {
  description = "Sorted comma-joined subnet IDs actually attached to the gateway ALB (after apply). Used to order CloudFront VPC origin create/update after ALB subnet shrinks."
  value       = terraform_data.alb_subnets_applied.output
}
