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
  description = "The ARN of the quarantine warmup lambda function. Only created when use_deployment_mode_external_eks is false."
  value       = var.use_quarantine_vpc && !var.use_deployment_mode_external_eks ? aws_lambda_function.quarantine_warmup[0].arn : null
}

output "lambda_security_group_id" {
  description = "The ID of the security group for the Lambda functions"
  value       = aws_security_group.lambda.id
}

output "quarantine_lambda_security_group_id" {
  description = "The ID of the security group for the quarantine Lambda functions"
  value       = var.quarantine_lambda_security_group_id
}

output "ai_proxy_url_ssm_arn" {
  description = "The ARN of the SSM parameter containing the AI proxy URL"
  value       = aws_ssm_parameter.ai_proxy_url.arn
}

