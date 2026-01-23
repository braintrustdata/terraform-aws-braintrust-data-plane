output "ai_proxy_url" {
  description = "The URL of the AI proxy lambda function"
  value       = aws_lambda_function_url.ai_proxy.function_url
}

output "api_handler_arn" {
  description = "The ARN of the API handler lambda function"
  value       = aws_lambda_function.api_handler.arn
}

output "ai_proxy_arn" {
  description = "The ARN of the AI proxy lambda function"
  value       = aws_lambda_function.ai_proxy.arn
}

output "migrate_database_arn" {
  description = "The ARN of the migrate database lambda function"
  value       = aws_lambda_function.migrate_database.arn
}

output "catchup_etl_arn" {
  description = "The ARN of the catchup etl lambda function"
  value       = aws_lambda_function.catchup_etl.arn
}

output "quarantine_warmup_arn" {
  description = "The ARN of the quarantine warmup lambda function"
  value       = var.use_quarantine_vpc ? aws_lambda_function.quarantine_warmup[0].arn : null
}

output "lambda_security_group_id" {
  description = "The ID of the security group for the Lambda functions"
  value       = aws_security_group.lambda.id
}

output "quarantine_lambda_security_group_id" {
  description = "The ID of the security group for the quarantine Lambda functions"
  value       = var.use_quarantine_vpc ? aws_security_group.quarantine_lambda[0].id : null
}

output "ai_proxy_url_ssm_arn" {
  description = "The ARN of the SSM parameter containing the AI proxy URL"
  value       = aws_ssm_parameter.ai_proxy_url.arn
}

# =============================================================================
# Brainstore EC2 Outputs
# =============================================================================

output "brainstore_dns_name" {
  description = "The DNS name of the Brainstore NLB"
  value       = var.brainstore_enabled ? module.brainstore[0].dns_name : null
}

output "brainstore_writer_dns_name" {
  description = "The DNS name of the Brainstore writer NLB"
  value       = var.brainstore_enabled && var.brainstore_writer_instance_count > 0 ? module.brainstore[0].writer_dns_name : null
}

output "brainstore_port" {
  description = "The port used by Brainstore"
  value       = var.brainstore_enabled ? module.brainstore[0].port : null
}

output "brainstore_elb_security_group_id" {
  description = "The ID of the security group for the Brainstore ELB"
  value       = var.brainstore_enabled ? module.brainstore[0].brainstore_elb_security_group_id : null
}

