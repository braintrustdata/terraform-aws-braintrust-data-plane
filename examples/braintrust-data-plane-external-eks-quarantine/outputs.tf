# Outputs from the Braintrust data plane module
output "quarantine_vpc_id" {
  description = "ID of the quarantine VPC that user functions run inside of."
  value       = module.braintrust-data-plane.quarantine_vpc_id
}

output "quarantine_invoke_role_arn" {
  description = "ARN of the IAM role used by the API handler to invoke quarantined functions"
  value       = module.braintrust-data-plane.quarantine_invoke_role_arn
}

output "quarantine_function_role_arn" {
  description = "ARN of the IAM role used by quarantined Lambda functions"
  value       = module.braintrust-data-plane.quarantine_function_role_arn
}

output "quarantine_private_subnet_1_id" {
  description = "ID of the first private subnet in the quarantine VPC"
  value       = module.braintrust-data-plane.quarantine_private_subnet_1_id
}

output "quarantine_private_subnet_2_id" {
  description = "ID of the second private subnet in the quarantine VPC"
  value       = module.braintrust-data-plane.quarantine_private_subnet_2_id
}

output "quarantine_private_subnet_3_id" {
  description = "ID of the third private subnet in the quarantine VPC"
  value       = module.braintrust-data-plane.quarantine_private_subnet_3_id
}

output "quarantine_lambda_security_group_id" {
  description = "ID of the security group for quarantine Lambda functions"
  value       = module.braintrust-data-plane.quarantine_lambda_security_group_id
}

output "main_vpc_id" {
  description = "ID of the main VPC"
  value       = module.braintrust-data-plane.main_vpc_id
}

output "api_security_group_id" {
  description = "ID of the security group for the API handler"
  value       = module.braintrust-data-plane.api_security_group_id
}

output "kms_key_arn" {
  description = "ARN of the KMS key used to encrypt Braintrust resources"
  value       = module.braintrust-data-plane.kms_key_arn
}
