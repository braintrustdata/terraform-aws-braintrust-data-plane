output "loop_runtime_alb_dns_name" {
  description = "Internal DNS name of the private Loop runtime ALB"
  value       = aws_lb.loop_runtime.dns_name
}

output "loop_runtime_alb_arn" {
  description = "ARN of the private Loop runtime ALB"
  value       = aws_lb.loop_runtime.arn
}

output "loop_runtime_alb_security_group_id" {
  description = "Security group ID attached to the private Loop runtime ALB"
  value       = aws_security_group.loop_runtime_alb.id
}

output "loop_runtime_target_group_arn" {
  description = "ARN of the Loop runtime ALB target group"
  value       = aws_lb_target_group.loop_runtime.arn
}

output "loop_runtime_http_listener_arn" {
  description = "ARN of the Loop runtime ALB HTTP listener"
  value       = aws_lb_listener.loop_runtime_http.arn
}

output "loop_runtime_url" {
  description = "Private in-VPC Loop runtime URL for LOOP_RUNTIME_URL on api-ts services"
  value       = "http://${aws_lb.loop_runtime.dns_name}:${local.loop_runtime_container_port}"
}

output "loop_runtime_cloudfront_vpc_origin_ingress_rule_id" {
  description = "Security group ingress rule allowing CloudFront VPC origins to reach the Loop runtime ALB."
  value       = try(aws_vpc_security_group_ingress_rule.loop_runtime_alb_from_cloudfront_vpc_origin[0].id, null)
}
