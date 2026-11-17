output "brainstore_instance_security_group_id" {
  description = "The ID of the security group for the Brainstore instances"
  value       = aws_security_group.brainstore_instance.id
}

output "api_security_group_id" {
  description = "The ID of the security group for the API handler"
  value       = aws_security_group.api.id
}

output "function_tools_secret_key" {
  description = "The function tools encryption key. This is used by Lambda services."
  value       = aws_secretsmanager_secret_version.function_tools_secret.secret_string
  sensitive   = true
}

output "function_tools_secret_arn" {
  description = "ARN of the function tools encryption key secret."
  value       = aws_secretsmanager_secret.function_tools_secret.arn
}

output "quarantine_lambda_security_group_id" {
  description = "The ID of the security group for quarantine Lambda functions"
  value       = one(aws_security_group.quarantine_lambda[*].id)
}
