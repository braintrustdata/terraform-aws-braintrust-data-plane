output "main_vpc_id" {
  value       = module.main_vpc.vpc_id
  description = "ID of the main VPC that contains the Braintrust resources"
}

output "quarantine_vpc_id" {
  value       = var.enable_quarantine_vpc ? module.quarantine_vpc[0].vpc_id : null
  description = "ID of the quarantine VPC that user functions run inside of."
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

output "clickhouse_secret_arn" {
  value       = try(module.clickhouse[0].clickhouse_secret_arn, null)
  description = "ARN of the Clickhouse secret"
}

output "clickhouse_s3_bucket_name" {
  value       = try(module.clickhouse[0].clickhouse_s3_bucket_name, null)
  description = "Name of the Clickhouse S3 bucket"
}

output "clickhouse_host" {
  value       = try(module.clickhouse[0].clickhouse_instance_private_ip, null)
  description = "Host of the Clickhouse instance"
}
