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

## EKS Auto Mode cluster (create_eks_cluster = true)
##
## Exposed so consumers can configure the kubernetes/helm providers
## directly from these outputs, skipping the `data.aws_eks_cluster`
## round-trip. Referencing these (rather than a data source) lets
## Terraform treat them as "known after apply" and defer provider
## resolution until the cluster exists — enabling a single-apply
## first deployment.

output "eks_cluster_name" {
  value       = var.create_eks_cluster ? module.eks_cluster[0].cluster_name : null
  description = "Name of the EKS cluster (null unless create_eks_cluster = true)."
}

output "eks_cluster_endpoint" {
  value       = var.create_eks_cluster ? module.eks_cluster[0].cluster_endpoint : null
  description = "EKS API server endpoint (null unless create_eks_cluster = true)."
}

output "eks_cluster_ca_certificate_data" {
  value       = var.create_eks_cluster ? module.eks_cluster[0].cluster_certificate_authority_data : null
  sensitive   = true
  description = "Base64-encoded cluster CA data (null unless create_eks_cluster = true)."
}

output "eks_cluster_security_group_id" {
  value       = var.create_eks_cluster ? module.eks_cluster[0].cluster_security_group_id : null
  description = "Primary security group the EKS control plane attaches to Auto Mode nodes (used to authorize RDS/Redis ingress)."
}

output "eks_nlb_arn" {
  value       = var.create_eks_cluster ? module.eks_cluster[0].nlb_arn : null
  description = "ARN of the pre-created internal NLB adopted by the AWS Load Balancer Controller."
}

output "eks_nlb_name" {
  value       = var.create_eks_cluster ? module.eks_cluster[0].nlb_name : null
  description = "Name of the pre-created NLB (referenced by the chart's aws-load-balancer-name annotation)."
}

output "nlb_security_group_id" {
  value       = var.create_eks_cluster ? module.eks_cluster[0].nlb_security_group_id : null
  description = "Security group ID attached to the NLB."
}

## Storage (S3 bucket names)

output "code_bundle_bucket_id" {
  value       = module.storage.code_bundle_bucket_id
  description = "Name of the code-bundle S3 bucket."
}

output "lambda_responses_bucket_id" {
  value       = module.storage.lambda_responses_bucket_id
  description = "Name of the lambda-responses S3 bucket."
}

## Database + Redis connection details

output "postgres_database_address" {
  value       = module.database.postgres_database_address
  description = "Hostname of the main Postgres database."
}

output "postgres_database_port" {
  value       = module.database.postgres_database_port
  description = "Port of the main Postgres database."
}

output "postgres_database_username" {
  value       = module.database.postgres_database_username
  description = "Username for the main Postgres database."
}

output "postgres_database_password" {
  value       = module.database.postgres_database_password
  sensitive   = true
  description = "Password for the main Postgres database."
}

output "redis_endpoint" {
  value       = module.redis.redis_endpoint
  description = "Hostname of the Redis instance."
}

output "redis_port" {
  value       = module.redis.redis_port
  description = "Port of the Redis instance."
}

## IAM roles (for downstream IRSA/Pod Identity wiring in external consumers)

output "api_handler_role_arn" {
  value       = module.services_common.api_handler_role_arn
  description = "ARN of the IAM role used by the API (braintrust-api service account Pod Identity association)."
}

output "brainstore_iam_role_arn" {
  value       = module.services_common.brainstore_iam_role_arn
  description = "ARN of the IAM role used by Brainstore (brainstore service account Pod Identity association; also the EC2 role on the EC2-Brainstore path)."
}

output "function_tools_secret_key" {
  value       = module.services_common.function_tools_secret_key
  sensitive   = true
  description = "Encryption key for function tool credentials (used by Brainstore as SERVICE_TOKEN_SECRET_KEY)."
}
