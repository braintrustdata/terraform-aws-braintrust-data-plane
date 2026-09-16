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

output "private_endpoint_dependency_ids" {
  description = "Endpoint and access rule IDs that must exist before the runtime service starts."
  value = [
    aws_vpc_endpoint.loop_runtime_microvm.id,
    aws_vpc_security_group_ingress_rule.loop_runtime_microvm_https.id,
  ]
}
