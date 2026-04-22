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
  value       = !var.use_deployment_mode_external_eks ? module.services[0].lambda_security_group_id : null
  description = "ID of the security group for the Lambda functions"
}

output "api_security_group_id" {
  value       = module.services_common.api_security_group_id
  description = "ID of the security group for the API handler"
}

output "ecs_cluster_arn" {
  value       = var.enable_llm_gateway ? module.ecs[0].cluster_arn : null
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
  value = !var.use_deployment_mode_external_eks ? module.ingress[0].api_url : (
    var.create_eks_cluster ? "https://${local.eks_cloudfront_domain_name}" : null
  )
  description = "The primary endpoint for the dataplane API. This is the value that should be entered into the braintrust dashboard under API URL."
}

output "cloudfront_distribution_domain_name" {
  value = !var.use_deployment_mode_external_eks ? module.ingress[0].cloudfront_distribution_domain_name : (
    var.create_eks_cluster ? local.eks_cloudfront_domain_name : null
  )
  description = "The domain name of the cloudfront distribution"
}

output "cloudfront_distribution_arn" {
  value = !var.use_deployment_mode_external_eks ? module.ingress[0].cloudfront_distribution_arn : (
    var.create_eks_cluster ? local.eks_cloudfront_arn : null
  )
  description = "The ARN of the cloudfront distribution"
}

output "cloudfront_distribution_hosted_zone_id" {
  value = !var.use_deployment_mode_external_eks ? module.ingress[0].cloudfront_distribution_hosted_zone_id : (
    var.create_eks_cluster ? local.eks_cloudfront_hosted_zone_id : null
  )
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

## IAM role ARNs (useful for EKS IRSA configuration)

output "brainstore_iam_role_arn" {
  value       = module.services_common.brainstore_iam_role_arn
  description = "ARN of the IAM role for Brainstore (used for IRSA service account annotation)"
}

output "api_handler_role_arn" {
  value       = module.services_common.api_handler_role_arn
  description = "ARN of the IAM role for the API handler (used for IRSA service account annotation)"
}

output "function_tools_secret_key" {
  value       = module.services_common.function_tools_secret_key
  sensitive   = true
  description = "The function tools encryption key used by Brainstore as SERVICE_TOKEN_SECRET_KEY"
}

## Storage bucket names

output "code_bundle_bucket_id" {
  value       = module.storage.code_bundle_bucket_id
  description = "Name of the code bundle S3 bucket"
}

output "lambda_responses_bucket_id" {
  value       = module.storage.lambda_responses_bucket_id
  description = "Name of the lambda responses S3 bucket"
}

## Database connection details (for EKS Kubernetes secret construction)

output "postgres_database_address" {
  value       = module.database.postgres_database_address
  description = "Hostname of the main Postgres database"
}

output "postgres_database_port" {
  value       = module.database.postgres_database_port
  description = "Port of the main Postgres database"
}

output "postgres_database_username" {
  value       = module.database.postgres_database_username
  description = "Username for the main Postgres database"
}

output "postgres_database_password" {
  value       = module.database.postgres_database_password
  sensitive   = true
  description = "Password for the main Postgres database"
}

## Redis connection details

output "redis_endpoint" {
  value       = module.redis.redis_endpoint
  description = "Hostname of the Redis instance"
}

output "redis_port" {
  value       = module.redis.redis_port
  description = "Port of the Redis instance"
}

## EKS cluster outputs (only populated when create_eks_cluster = true)

output "eks_cluster_name" {
  value       = local.eks_cluster_name_val
  description = "Name of the EKS cluster (null when create_eks_cluster = false)"
}

output "eks_cluster_endpoint" {
  value       = local.eks_cluster_endpoint_val
  description = "API server endpoint of the EKS cluster (null when create_eks_cluster = false)"
}

output "eks_cluster_ca_certificate" {
  value       = local.eks_cluster_ca_certificate_val
  sensitive   = true
  description = "Base64-encoded certificate authority data for the EKS cluster"
}

output "eks_oidc_provider_arn" {
  value       = local.eks_oidc_provider_arn
  description = "ARN of the IAM OIDC provider for the EKS cluster"
}

output "eks_node_security_group_id" {
  value       = local.eks_node_security_group_id
  description = "ID of the EKS node security group"
}

output "eks_lb_controller_role_arn" {
  value       = local.eks_lb_controller_role_arn
  description = "ARN of the IAM role for the AWS Load Balancer Controller"
}

output "eks_nlb_arn" {
  value       = local.eks_nlb_arn_val
  description = "ARN of the pre-created NLB for the EKS API service"
}

output "eks_nlb_name" {
  value       = local.eks_nlb_name_val
  description = "Name of the pre-created NLB (used for aws-load-balancer-name annotation)"
}

output "nlb_security_group_id" {
  value       = local.eks_nlb_security_group_id
  description = "ID of the NLB CloudFront security group"
}
