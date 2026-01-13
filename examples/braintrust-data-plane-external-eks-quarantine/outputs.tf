# Outputs from the Braintrust data plane module
output "quarantine_vpc_id" {
  description = "ID of the quarantine VPC that user functions run inside of."
  value       = module.braintrust-data-plane.quarantine_vpc_id
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
