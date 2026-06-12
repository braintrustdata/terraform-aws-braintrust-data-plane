output "brainstore_instance_security_group_id" {
  description = "The ID of the security group for the Brainstore instances"
  value       = aws_security_group.brainstore_instance.id
}

output "brainstore_iam_role_arn" {
  description = "The ARN of the IAM role for Brainstore instances (supports EC2, EKS Pod Identity, and IRSA)"
  value       = aws_iam_role.brainstore_role.arn
}

output "brainstore_iam_role_name" {
  description = "The name of the IAM role for Brainstore instances (supports EC2, EKS Pod Identity, and IRSA)"
  value       = aws_iam_role.brainstore_role.name
}

output "api_handler_role_arn" {
  description = "The ARN of the IAM role for the API handler"
  value       = aws_iam_role.api_handler_role.arn
}

output "api_handler_role_name" {
  description = "The name of the IAM role for the API handler"
  value       = aws_iam_role.api_handler_role.name
}

output "api_security_group_id" {
  description = "The ID of the security group for the API handler"
  value       = aws_security_group.api.id
}

output "gateway_alb_security_group_id" {
  description = "The ID of the security group for the internal AI gateway ALB"
  value       = one(aws_security_group.gateway_alb[*].id)
}

output "gateway_alb_arn" {
  description = "ARN of the private AI gateway ALB"
  value       = one(aws_lb.gateway[*].arn)
}

output "gateway_alb_dns_name" {
  description = "DNS name of the private AI gateway ALB"
  value       = one(aws_lb.gateway[*].dns_name)
}

output "gateway_target_group_arn" {
  description = "ARN of the AI gateway ALB target group"
  value       = one(aws_lb_target_group.gateway[*].arn)
}

output "function_tools_secret_key" {
  description = "The function tools encryption key. This is used by brainstore as the SERVICE_TOKEN_SECRET_KEY."
  value       = aws_secretsmanager_secret_version.function_tools_secret.secret_string
  sensitive   = true
}

output "function_tools_secret_arn" {
  description = "ARN of the function tools encryption key secret."
  value       = aws_secretsmanager_secret.function_tools_secret.arn
}

output "quarantine_invoke_role_arn" {
  description = "The ARN of the IAM role used by the API handler to invoke quarantined functions"
  value       = one(aws_iam_role.quarantine_invoke_role[*].arn)
}

output "quarantine_function_role_arn" {
  description = "The ARN of the IAM role used by quarantined Lambda functions"
  value       = one(aws_iam_role.quarantine_function_role[*].arn)
}

output "quarantine_lambda_security_group_id" {
  description = "The ID of the security group for quarantine Lambda functions"
  value       = one(aws_security_group.quarantine_lambda[*].id)
}
