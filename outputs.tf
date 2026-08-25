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

output "quarantine_gateway_privatelink_service_name" {
  value       = local.create_quarantine_gateway_privatelink ? aws_vpc_endpoint_service.gateway_quarantine[0].service_name : null
  description = "VPC endpoint service name for quarantine→private gateway PrivateLink (null unless use_private_gateway_quarantine_proxy with module-managed VPCs). Existing VPC / existing quarantine callers must set quarantine_proxy_url; use this name if you attach a manual interface endpoint."
}

output "quarantine_gateway_privatelink_endpoint_dns_name" {
  value       = local.create_quarantine_gateway_privatelink ? aws_vpc_endpoint.quarantine_gateway[0].dns_entry[0].dns_name : null
  description = "DNS name of the quarantine VPC endpoint to the private gateway (null unless PrivateLink consumer is created)"
}

output "brainstore_security_group_id" {
  value       = module.services_common.brainstore_instance_security_group_id
  description = "ID of the security group for the Brainstore instances"
}

output "brainstore_s3_bucket_name" {
  value       = module.storage.brainstore_bucket_id
  description = "Name of the Brainstore S3 bucket"
}

output "code_bundle_s3_bucket_name" {
  value       = module.storage.code_bundle_bucket_id
  description = "Name of the code bundle S3 bucket"
}

output "lambda_responses_s3_bucket_name" {
  value       = module.storage.lambda_responses_bucket_id
  description = "Name of the lambda responses S3 bucket"
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
  value       = local.create_ai_gateway || local.create_ecs_api ? module.ecs[0].cluster_arn : null
  description = "ARN of the ECS cluster used for ECS services"
}

output "gateway_service_name" {
  value       = local.create_ai_gateway ? module.gateway_ecs[0].service_name : null
  description = "Name of the ECS gateway service"
}

output "gateway_alb_dns_name" {
  value       = local.create_ai_gateway ? module.gateway_alb[0].gateway_alb_dns_name : null
  description = "Internal DNS name of the private gateway ALB"
}

output "gateway_alb_arn" {
  value       = local.create_ai_gateway ? module.gateway_alb[0].gateway_alb_arn : null
  description = "ARN of the private gateway ALB"
}

output "gateway_alb_subnet_ids" {
  value       = local.create_ai_gateway ? module.gateway_alb[0].gateway_alb_subnet_ids : null
  description = "Subnet IDs attached to the private gateway ALB."
}

output "gateway_target_group_arn" {
  value       = local.create_ai_gateway ? module.gateway_alb[0].gateway_target_group_arn : null
  description = "ARN of the gateway ALB target group"
}

output "gateway_url" {
  value       = local.create_ai_gateway ? module.gateway_alb[0].gateway_url : null
  description = "Private in-VPC gateway URL. Set enable_ai_gateway to wire GATEWAY_URL on api-ts services."
}

output "gateway_task_security_group_id" {
  value       = local.create_ai_gateway ? module.gateway_ecs[0].task_security_group_id : null
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
  description = "URL of the private API ECS ALB (https://<custom domain> when a certificate and custom domain are provided, otherwise http://<ALB DNS name>)"
}

output "quarantine_proxy_url" {
  value       = local.create_ecs_api ? local.api_ecs_quarantine_proxy_url : null
  description = "Effective QUARANTINE_PROXY_URL on API ECS (quarantine_proxy_url override, PrivateLink VPCE /v1/proxy when use_private_gateway_quarantine_proxy, otherwise AI Proxy Function URL)"
}

output "api_ecs_task_security_group_id" {
  value       = local.create_ecs_api ? module.api_ecs[0].task_security_group_id : null
  description = "ID of the security group for API ECS tasks"
}

output "loop_runtime_url" {
  value       = local.create_loop_runtime ? module.loop_runtime_alb[0].loop_runtime_url : null
  description = "Private in-VPC URL of the Loop runtime ALB"
}

output "loop_runtime_microvm_image_arn" {
  value       = local.create_loop_runtime ? module.loop_runtime_sandbox_aws_microvm[0].image_arn : null
  description = "ARN of the Loop runtime sandbox MicroVM image"
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

output "monitoring_contract" {
  description = "Versioned resource identifiers and capabilities consumed by terraform-aws-braintrust-data-plane-cloudwatch."
  value = {
    version = 2

    rds = {
      identifier               = module.database.postgres_database_identifier
      allocated_storage_gib    = module.database.postgres_allocated_storage_gib
      provisioned_iops         = module.database.postgres_provisioned_iops
      provisioned_iops_enabled = var.postgres_storage_iops == null ? false : var.postgres_storage_iops > 0
    }

    elasticache = module.redis.monitoring_target

    lambda = {
      enabled   = !var.use_deployment_mode_external_eks
      functions = !var.use_deployment_mode_external_eks ? module.services[0].monitoring_functions : {}
    }

    api_gateway = {
      enabled = !var.use_deployment_mode_external_eks
      name    = !var.use_deployment_mode_external_eks ? module.ingress[0].api_gateway_name : null
      stage   = !var.use_deployment_mode_external_eks ? module.ingress[0].api_gateway_stage_name : null
    }

    brainstore = {
      enabled        = !var.use_deployment_mode_external_eks
      s3_bucket_name = module.storage.brainstore_bucket_id
      targets        = !var.use_deployment_mode_external_eks ? module.brainstore[0].monitoring_targets : {}
    }

    cloudfront = {
      enabled         = !var.use_deployment_mode_external_eks
      distribution_id = !var.use_deployment_mode_external_eks ? module.ingress[0].cloudfront_distribution_id : null
    }

    ecs = {
      enabled      = length(module.ecs) > 0
      cluster_name = length(module.ecs) > 0 ? module.ecs[0].cluster_name : null
      services = merge(
        local.create_ecs_api ? {
          for role, target in module.api_ecs[0].monitoring_targets : role => merge(
            target,
            { lb_arn_suffix = module.api_ecs[0].alb_arn_suffix },
          )
        } : {},
        local.create_ai_gateway ? {
          gateway = {
            alarm_group   = "gateway"
            service_name  = module.gateway_ecs[0].service_name
            lb_arn_suffix = module.gateway_alb[0].gateway_alb_arn_suffix
            tg_arn_suffix = module.gateway_alb[0].gateway_target_group_arn_suffix
          }
        } : {},
      )
    }

    cloudwatch = {
      log_groups = merge(
        local.create_ecs_api ? { api-ecs = module.api_ecs[0].cloudwatch_log_groups } : {},
        local.create_ai_gateway ? { gateway = module.gateway_ecs[0].cloudwatch_log_groups } : {},
        local.create_loop_runtime ? { loop-runtime = module.loop_runtime_ecs[0].cloudwatch_log_groups } : {},
        local.create_loop_runtime ? { loop-runtime-sandbox = { group = module.loop_runtime_sandbox_aws_microvm[0].microvm_log_group_name } } : {},
      )
    }
  }
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
