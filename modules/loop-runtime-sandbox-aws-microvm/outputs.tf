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
  description = "Target group the Loop runtime ECS service registers its sandbox egress port with. Read from the listener so the service waits for it."
  value       = aws_lb_listener.egress_gateway.default_action[0].target_group_arn
}

output "egress_gateway_security_group_id" {
  description = "Security group of the sandbox egress gateway NLB. The Loop runtime tasks must accept its traffic on port 4002."
  value       = aws_security_group.egress_gateway_nlb.id
}

output "egress_gateway_dns_name" {
  description = "DNS name of the sandbox egress gateway endpoint. With existing_vpc_id, the caller's DNS policy must let sandboxes resolve it."
  value       = local.egress_gateway_dns_name
}
