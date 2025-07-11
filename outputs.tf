output "main_vpc_id" {
  value       = module.main_vpc.vpc_id
  description = "ID of the main VPC that contains the Braintrust resources"
}

output "quarantine_vpc_id" {
  value       = var.enable_quarantine_vpc ? module.quarantine_vpc[0].vpc_id : null
  description = "ID of the quarantine VPC that user functions run inside of."
}

output "main_vpc_cidr" {
  value       = module.main_vpc.vpc_cidr
  description = "CIDR block of the main VPC"
}

output "main_vpc_public_subnet_1_id" {
  value       = module.main_vpc.public_subnet_1_id
  description = "ID of the public subnet in the main VPC"
}

output "main_vpc_private_subnet_1_id" {
  value       = module.main_vpc.private_subnet_1_id
  description = "ID of the first private subnet in the main VPC"
}

output "main_vpc_private_subnet_2_id" {
  value       = module.main_vpc.private_subnet_2_id
  description = "ID of the second private subnet in the main VPC"
}

output "main_vpc_private_subnet_3_id" {
  value       = module.main_vpc.private_subnet_3_id
  description = "ID of the third private subnet in the main VPC"
}

output "main_vpc_public_route_table_id" {
  value       = module.main_vpc.public_route_table_id
  description = "ID of the public route table in the main VPC"
}

output "main_vpc_private_route_table_id" {
  value       = module.main_vpc.private_route_table_id
  description = "ID of the private route table in the main VPC"
}

output "brainstore_security_group_id" {
  value       = module.brainstore[0].brainstore_instance_security_group_id
  description = "ID of the security group for the Brainstore instances"
}

output "database_security_group_id" {
  value       = module.database.database_security_group_id
  description = "ID of the security group for the RDS instance"
}

output "elasticache_security_group_id" {
  value       = module.elasticache.elasticache_security_group_id
  description = "ID of the security group for the Elasticache instance"
}

output "lambda_security_group_id" {
  value       = module.services.lambda_security_group_id
  description = "ID of the security group for the Lambda functions"
}

output "postgres_database_arn" {
  value       = module.database.postgres_database_arn
  description = "ARN of the main Braintrust Postgres database"
}

output "redis_arn" {
  value       = module.redis.redis_arn
  description = "ARN of the Redis instance"
}

output "api_url" {
  value       = module.services.api_url
  description = "The primary endpoint for the dataplane API. This is the value that should be entered into the braintrust dashboard under API URL."
}

output "clickhouse_secret_id" {
  value       = try(module.clickhouse[0].clickhouse_secret_id, null)
  description = "ID of the Clickhouse secret. Note this is the Terraform ID attribute which is a pipe delimited combination of secret ID and version ID"
}

output "clickhouse_s3_bucket_name" {
  value       = try(module.clickhouse[0].clickhouse_s3_bucket_name, null)
  description = "Name of the Clickhouse S3 bucket"
}

output "clickhouse_host" {
  value       = try(module.clickhouse[0].clickhouse_instance_private_ip, null)
  description = "Host of the Clickhouse instance"
}
