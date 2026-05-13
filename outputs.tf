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
  description = "ID of the first public subnet in the main VPC"
}

output "main_vpc_public_subnet_2_id" {
  value       = local.main_vpc_public_subnet_2_id
  description = "ID of the second public subnet in the main VPC (null when create_vpc is false)"
}

output "main_vpc_public_subnet_3_id" {
  value       = local.main_vpc_public_subnet_3_id
  description = "ID of the third public subnet in the main VPC (null when create_vpc is false)"
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

output "code_bundle_s3_bucket_name" {
  value       = module.storage.code_bundle_bucket_id
  description = "Name of the S3 bucket used for uploaded code bundles"
}

output "lambda_responses_s3_bucket_name" {
  value       = module.storage.lambda_responses_bucket_id
  description = "Name of the S3 bucket used for lambda response payloads"
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
  value       = !local.use_eks ? module.services[0].lambda_security_group_id : null
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

output "redis_endpoint" {
  value       = module.redis.redis_endpoint
  description = "Hostname of the ElastiCache Redis instance"
}

output "redis_port" {
  value       = module.redis.redis_port
  description = "Port of the ElastiCache Redis instance"
}

output "postgres_database_address" {
  value       = module.database.postgres_database_address
  description = "Hostname of the RDS PostgreSQL instance"
}

output "postgres_database_port" {
  value       = module.database.postgres_database_port
  description = "Port of the RDS PostgreSQL instance"
}

output "postgres_database_username" {
  value       = module.database.postgres_database_username
  description = "Username of the RDS PostgreSQL instance"
}

output "postgres_database_password" {
  value       = module.database.postgres_database_password
  description = "Password of the RDS PostgreSQL instance"
  sensitive   = true
}

output "api_url" {
  value       = !local.use_eks ? module.ingress[0].api_url : (var.create_eks_cluster ? module.eks_cluster[0].api_url : null)
  description = "The primary endpoint for the dataplane API. This is the value that should be entered into the Braintrust dashboard under API URL. Null when create_eks_cluster is true and eks_enable_cloudfront_nlb_ingress is false."
}

output "cloudfront_distribution_domain_name" {
  value       = !local.use_eks ? module.ingress[0].cloudfront_distribution_domain_name : (var.create_eks_cluster ? module.eks_cluster[0].cloudfront_distribution_domain_name : null)
  description = "The domain name of the CloudFront distribution. Null when create_eks_cluster is true and eks_enable_cloudfront_nlb_ingress is false."
}

output "cloudfront_distribution_arn" {
  value       = !local.use_eks ? module.ingress[0].cloudfront_distribution_arn : (var.create_eks_cluster ? module.eks_cluster[0].cloudfront_distribution_arn : null)
  description = "The ARN of the cloudfront distribution"
}

output "cloudfront_distribution_hosted_zone_id" {
  value       = !local.use_eks ? module.ingress[0].cloudfront_distribution_hosted_zone_id : (var.create_eks_cluster ? module.eks_cluster[0].cloudfront_distribution_hosted_zone_id : null)
  description = "The hosted zone ID of the CloudFront distribution. Null when create_eks_cluster is true and eks_enable_cloudfront_nlb_ingress is false."
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

output "eks_cluster_name" {
  value       = var.create_eks_cluster ? module.eks_cluster[0].cluster_name : null
  description = "Name of the EKS cluster created by this module. Null when create_eks_cluster is false."
}

output "eks_cluster_security_group_id" {
  value       = var.create_eks_cluster ? module.eks_cluster[0].cluster_security_group_id : null
  description = "Security group ID attached to the EKS cluster nodes. Null when create_eks_cluster is false."
}

output "eks_cluster_arn" {
  value       = var.create_eks_cluster ? module.eks_cluster[0].cluster_arn : null
  description = "ARN of the EKS cluster created by this module. Null when create_eks_cluster is false."
}

output "eks_cluster_endpoint" {
  value       = var.create_eks_cluster ? module.eks_cluster[0].cluster_endpoint : null
  description = "API server endpoint of the EKS cluster. Null when create_eks_cluster is false."
}

output "eks_cluster_oidc_issuer_url" {
  value       = var.create_eks_cluster ? module.eks_cluster[0].cluster_oidc_issuer_url : null
  description = "OIDC issuer URL of the EKS cluster, used for IRSA. Null when create_eks_cluster is false."
}

output "eks_cluster_certificate_authority_data" {
  value       = var.create_eks_cluster ? module.eks_cluster[0].cluster_certificate_authority_data : null
  description = "Base64-encoded certificate authority data for the EKS cluster."
  sensitive   = true
}

output "eks_node_group_iam_role_arn" {
  value       = var.create_eks_cluster ? module.eks_cluster[0].node_group_iam_role_arn : null
  description = "IAM role ARN shared by all EKS node groups. Null when create_eks_cluster is false."
}

output "eks_node_group_iam_role_name" {
  value       = var.create_eks_cluster ? module.eks_cluster[0].node_group_iam_role_name : null
  description = "IAM role name shared by all EKS node groups. Null when create_eks_cluster is false."
}

output "eks_braintrust_api_role_arn" {
  value       = var.create_eks_cluster ? module.services_common.api_handler_role_arn : null
  description = "IAM role ARN for the Braintrust API Pod Identity association."
}

output "eks_brainstore_role_arn" {
  value       = var.create_eks_cluster ? module.services_common.brainstore_iam_role_arn : null
  description = "IAM role ARN for the Brainstore Pod Identity association."
}

output "eks_nlb_arn" {
  value       = var.create_eks_cluster ? module.eks_cluster[0].nlb_arn : null
  description = "ARN of the internal NLB used by the EKS API service."
}

output "eks_nlb_name" {
  value       = var.create_eks_cluster ? module.eks_cluster[0].nlb_name : null
  description = "Name of the internal NLB adopted by the Braintrust API Kubernetes service."
}

output "eks_nlb_security_group_id" {
  value       = var.create_eks_cluster ? module.eks_cluster[0].nlb_security_group_id : null
  description = "Security group ID attached to the internal NLB."
}

output "eks_namespace" {
  value       = var.create_eks_cluster ? local.eks_namespace_resolved : null
  description = "Kubernetes namespace where Braintrust workloads are deployed."
}

output "function_tools_secret_key" {
  value       = module.services_common.function_tools_secret_key
  description = "Secret key used by Braintrust application components for function tools authentication."
  sensitive   = true
}
