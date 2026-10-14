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

output "egress_gateway_target_group_arn" {
  description = "Egress gateway target group for the Loop runtime ECS service."
  # Read through the listener so the ECS service waits for it.
  value = aws_lb_listener.egress_gateway.default_action[0].target_group_arn
}

output "egress_gateway_security_group_id" {
  description = "Egress gateway NLB security group."
  value       = aws_security_group.egress_gateway_nlb.id
}

output "egress_gateway_dns_name" {
  description = "Egress gateway endpoint DNS name."
  value       = local.egress_gateway_dns_name
}
