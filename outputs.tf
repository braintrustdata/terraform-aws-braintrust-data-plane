output "main_vpc_id" {
  value       = local.main_vpc_id
  description = "ID of the main VPC that contains the Braintrust resources"
}

output "quarantine_vpc_id" {
  value       = var.enable_quarantine_vpc ? module.quarantine_vpc[0].vpc_id : null
  description = "ID of the quarantine VPC that user functions run inside of."
}

output "main_vpc_cidr" {
  value       = var.create_vpc ? module.main_vpc[0].vpc_cidr : null
  description = "CIDR block of the main VPC"
}

output "main_vpc_public_subnet_1_id" {
  value       = local.main_vpc_public_subnet_1_id
  description = "ID of the public subnet in the main VPC"
}

output "main_vpc_private_subnet_1_id" {
  value       = local.main_vpc_private_subnet_1_id
  description = "ID of the first private subnet in the main VPC"
}

output "main_vpc_private_subnet_2_id" {
  value       = local.main_vpc_private_subnet_2_id
  description = "ID of the second private subnet in the main VPC"
}

output "main_vpc_private_subnet_3_id" {
  value       = local.main_vpc_private_subnet_3_id
  description = "ID of the third private subnet in the main VPC"
}

output "main_vpc_public_route_table_id" {
  value       = var.create_vpc ? module.main_vpc[0].public_route_table_id : null
  description = "ID of the public route table in the main VPC (null when using existing VPC)"
}

output "main_vpc_private_route_table_id" {
  value       = var.create_vpc ? module.main_vpc[0].private_route_table_id : null
  description = "ID of the private route table in the main VPC (null when using existing VPC)"
}

output "brainstore_security_group_id" {
  value       = var.enable_brainstore ? module.services_common.brainstore_instance_security_group_id : null
  description = "ID of the security group for the Brainstore instances"
}

output "brainstore_s3_bucket_name" {
  value       = var.enable_brainstore ? module.storage.brainstore_bucket_id : null
  description = "Name of the Brainstore S3 bucket"
}

output "rds_security_group_id" {
  value       = module.database.rds_security_group_id
  description = "ID of the security group for the RDS instance"
}

output "redis_security_group_id" {
  value       = module.redis.redis_security_group_id
  description = "ID of the security group for the Elasticache instance"
}

output "lambda_security_group_id" {
  value       = !var.use_deployment_mode_external_eks ? module.services[0].lambda_security_group_id : null
  description = "ID of the security group for the Lambda functions"
}

output "api_security_group_id" {
  value       = module.services_common.api_security_group_id
  description = "ID of the security group for the API handler"
}

output "postgres_database_identifier" {
  value       = module.database.postgres_database_identifier
  description = "Identifier of the main Braintrust Postgres database"
}

output "postgres_database_arn" {
  value       = module.database.postgres_database_arn
  description = "ARN of the main Braintrust Postgres database"
}

output "postgres_database_secret_arn" {
  value       = module.database.postgres_database_secret_arn
  description = "ARN of the secret containing the main Postgres database credentials"
}

output "redis_arn" {
  value       = module.redis.redis_arn
  description = "ARN of the Redis instance"
}

output "api_url" {
  value       = !var.use_deployment_mode_external_eks ? module.ingress[0].api_url : null
  description = "The primary endpoint for the dataplane API. This is the value that should be entered into the braintrust dashboard under API URL."
}

output "cloudfront_distribution_domain_name" {
  value       = !var.use_deployment_mode_external_eks ? module.ingress[0].cloudfront_distribution_domain_name : null
  description = "The domain name of the cloudfront distribution"
}

output "cloudfront_distribution_arn" {
  value       = !var.use_deployment_mode_external_eks ? module.ingress[0].cloudfront_distribution_arn : null
  description = "The ARN of the cloudfront distribution"
}

output "cloudfront_distribution_hosted_zone_id" {
  value       = !var.use_deployment_mode_external_eks ? module.ingress[0].cloudfront_distribution_hosted_zone_id : null
  description = "The hosted zone ID of the cloudfront distribution"
}

output "kms_key_arn" {
  value       = local.kms_key_arn
  description = "ARN of the KMS key used to encrypt Braintrust resources"
}
