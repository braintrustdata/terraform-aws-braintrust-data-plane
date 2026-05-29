output "main_vpc_id" {
  value       = local.main_vpc_id
  description = "ID of the main VPC that contains the Braintrust resources"
}

output "quarantine_vpc_id" {
  value       = local.quarantine_vpc_id
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
  value       = local.create_lambda_services ? module.services[0].lambda_security_group_id : null
  description = "ID of the security group for the Lambda functions"
}

output "api_security_group_id" {
  value       = module.services_common.api_security_group_id
  description = "ID of the security group for the API handler"
}

output "ecs_cluster_arn" {
  value       = var.enable_llm_gateway || local.create_ecs_api ? module.ecs[0].cluster_arn : null
  description = "ARN of the ECS cluster used for ECS services"
}

output "gateway_service_name" {
  value       = var.enable_llm_gateway ? module.gateway_ecs[0].service_name : null
  description = "Name of the ECS gateway service"
}

output "gateway_alb_dns_name" {
  value       = var.enable_llm_gateway ? module.gateway_ecs[0].alb_dns_name : null
  description = "Internal DNS name of the private gateway ALB"
}

output "gateway_alb_arn" {
  value       = var.enable_llm_gateway ? module.gateway_ecs[0].alb_arn : null
  description = "ARN of the private gateway ALB"
}

output "gateway_target_group_arn" {
  value       = var.enable_llm_gateway ? module.gateway_ecs[0].target_group_arn : null
  description = "ARN of the gateway ALB target group"
}

output "gateway_task_security_group_id" {
  value       = var.enable_llm_gateway ? module.gateway_ecs[0].task_security_group_id : null
  description = "ID of the security group for ECS gateway tasks"
}

output "api_ecs_service_name" {
  value       = local.create_ecs_api ? module.api_ecs[0].service_name : null
  description = "Name of the ECS API service"
}

output "api_ecs_alb_arn" {
  value       = local.create_ecs_api ? module.api_ecs[0].alb_arn : null
  description = "ARN of the private API ECS ALB"
}

output "api_ecs_alb_dns_name" {
  value       = local.create_ecs_api ? module.api_ecs[0].alb_dns_name : null
  description = "DNS name of the private API ECS ALB"
}

output "api_ecs_alb_zone_id" {
  value       = local.create_ecs_api ? module.api_ecs[0].alb_zone_id : null
  description = "Hosted zone ID of the private API ECS ALB"
}

output "api_ecs_target_group_arn" {
  value       = local.create_ecs_api ? module.api_ecs[0].target_group_arn : null
  description = "ARN of the API ECS ALB target group"
}

output "api_ecs_alb_security_group_id" {
  value       = local.create_ecs_api ? module.api_ecs[0].alb_security_group_id : null
  description = "ID of the security group attached to the private API ECS ALB"
}

output "api_ecs_http_url" {
  value       = local.create_ecs_api ? module.api_ecs[0].http_url : null
  description = "HTTP URL clients should use for the private API ECS endpoint on port 8000"
}

output "api_ecs_https_url" {
  value       = local.create_ecs_api ? module.api_ecs[0].https_url : null
  description = "HTTPS URL of the private API ECS ALB when TLS is enabled"
}

output "api_ecs_client_url" {
  value       = local.create_ecs_api ? module.api_ecs[0].client_url : null
  description = "URL clients should use for the private API ECS ALB"
}

output "api_ecs_tls_ready" {
  value       = local.create_ecs_api ? module.api_ecs[0].tls_ready : null
  description = "Whether API ECS ALB HTTPS is enabled"
}

output "api_ecs_task_security_group_id" {
  value       = local.create_ecs_api ? module.api_ecs[0].task_security_group_id : null
  description = "ID of the security group for API ECS tasks"
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
  value       = local.api_url
  description = "The primary endpoint for the dataplane API. This is the value that should be entered into the braintrust dashboard under API URL."
}

output "cloudfront_distribution_domain_name" {
  value       = local.create_ingress ? module.ingress[0].cloudfront_distribution_domain_name : null
  description = "The domain name of the cloudfront distribution"
}

output "cloudfront_distribution_arn" {
  value       = local.create_ingress ? module.ingress[0].cloudfront_distribution_arn : null
  description = "The ARN of the cloudfront distribution"
}

output "cloudfront_distribution_hosted_zone_id" {
  value       = local.create_ingress ? module.ingress[0].cloudfront_distribution_hosted_zone_id : null
  description = "The hosted zone ID of the cloudfront distribution"
}

output "kms_key_arn" {
  value       = local.kms_key_arn
  description = "ARN of the KMS key used to encrypt Braintrust resources"
}

output "quarantine_invoke_role_arn" {
  value       = module.services_common.quarantine_invoke_role_arn
  description = "ARN of the IAM role used by the API handler to invoke quarantined functions"
}

output "quarantine_function_role_arn" {
  value       = module.services_common.quarantine_function_role_arn
  description = "ARN of the IAM role used by quarantined Lambda functions"
}

output "quarantine_private_subnet_1_id" {
  value       = local.quarantine_vpc_private_subnet_1_id
  description = "ID of the first private subnet in the quarantine VPC"
}

output "quarantine_private_subnet_2_id" {
  value       = local.quarantine_vpc_private_subnet_2_id
  description = "ID of the second private subnet in the quarantine VPC"
}

output "quarantine_private_subnet_3_id" {
  value       = local.quarantine_vpc_private_subnet_3_id
  description = "ID of the third private subnet in the quarantine VPC"
}

output "quarantine_lambda_security_group_id" {
  value       = module.services_common.quarantine_lambda_security_group_id
  description = "ID of the security group for quarantine Lambda functions"
}
