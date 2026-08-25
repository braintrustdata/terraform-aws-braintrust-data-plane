output "image_arn" {
  description = "ARN of the built Loop runtime sandbox MicroVM image."
  value       = local.image_arn
}

output "sandbox_env_vars" {
  description = "Environment variables the Loop runtime compute module merges into the container to drive this sandbox backend. Cloud-agnostic contract: a GKE/AKS sandbox module exposes the same output shape."
  value       = local.sandbox_env_vars
}

output "task_role_policy_json" {
  description = "IAM policy (JSON) the Loop runtime ECS task role must attach to drive MicroVMs. Cloud-agnostic contract: a GKE/AKS sandbox module exposes the same output shape (empty/adapted as needed)."
  value       = jsonencode(local.task_role_policy)
}

output "microvm_log_group_name" {
  description = "CloudWatch log group used for MicroVM image build and (opt-in) runtime logs."
  value       = aws_cloudwatch_log_group.microvm_image.name
}

output "restricted_egress_vpc_id" {
  description = "ID of the restricted-egress connector VPC (null unless sandbox_egress_mode is not internet)."
  value       = local.use_restricted_egress ? aws_vpc.restricted_egress[0].id : null
}

output "restricted_egress_subnet_ids" {
  description = "Subnet IDs in the restricted-egress connector VPC."
  value       = local.use_restricted_egress ? aws_subnet.restricted_egress[*].id : []
}

output "restricted_egress_security_group_id" {
  description = "Security group ID attached to the restricted-egress connector."
  value       = local.use_restricted_egress ? aws_security_group.restricted_egress[0].id : null
}

output "restricted_egress_firewall_rule_group_id" {
  description = "Route53 Resolver DNS Firewall rule group ID for the restricted-egress VPC."
  value       = local.use_restricted_egress ? aws_route53_resolver_firewall_rule_group.restricted_egress[0].id : null
}

output "loop_gateway_privatelink_endpoint_security_group_id" {
  description = "Security group ID for the Loop→gateway Interface VPCE (null unless create_privatelink_endpoint)."
  value       = local.use_restricted_egress && var.create_privatelink_endpoint ? aws_security_group.loop_gateway_privatelink_endpoint[0].id : null
}
