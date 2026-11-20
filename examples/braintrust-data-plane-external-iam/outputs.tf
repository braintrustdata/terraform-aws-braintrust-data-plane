# Outputs from the Braintrust data plane module
output "api_url" {
  description = "The URL of the Braintrust API"
  value       = module.braintrust-data-plane.api_url
}

output "quarantine_invoke_role_arn" {
  description = "ARN of the role that your security team created for the API handler to invoke quarantined functions"
  value       = module.braintrust-data-plane.quarantine_invoke_role_arn
}

output "quarantine_function_role_arn" {
  description = "ARN of the role that your security team created for quarantined Lambda functions"
  value       = module.braintrust-data-plane.quarantine_function_role_arn
}

output "kms_key_arn" {
  description = "ARN of the KMS key used to encrypt Braintrust resources"
  value       = module.braintrust-data-plane.kms_key_arn
}
