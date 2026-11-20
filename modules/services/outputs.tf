output "monitoring_functions" {
  description = "Core Lambda functions keyed by stable logical role for monitoring integrations."
  value = merge(
    {
      billing-cron = {
        function_name   = aws_lambda_function.billing_cron.function_name
        timeout_seconds = aws_lambda_function.billing_cron.timeout
      }
      automation-cron = {
        function_name   = aws_lambda_function.automation_cron.function_name
        timeout_seconds = aws_lambda_function.automation_cron.timeout
      }
      catchup-etl = {
        function_name   = aws_lambda_function.catchup_etl.function_name
        timeout_seconds = aws_lambda_function.catchup_etl.timeout
      }
    },
    var.enable_quarantine_pruner ? {
      quarantine-pruner = {
        function_name   = aws_lambda_function.quarantine_pruner[0].function_name
        timeout_seconds = aws_lambda_function.quarantine_pruner[0].timeout
      }
    } : {},
  )
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
  value       = one(aws_lambda_function.quarantine_warmup[*].arn)
}

output "lambda_security_group_id" {
  description = "The ID of the security group for the Lambda functions"
  value       = aws_security_group.lambda.id
}

output "quarantine_lambda_security_group_id" {
  description = "The ID of the security group for the quarantine Lambda functions"
  value       = var.quarantine_lambda_security_group_id
}

