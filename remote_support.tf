# This optional opt-in module allows Braintrust staff to access Cloudwatch logs or a Bastion host.
# It is disabled by default and can be enabled by setting the appropriate "enable_braintrust_support_*" variables.

locals {
  has_braintrust_support_access = var.enable_braintrust_support_logs_access || var.enable_braintrust_support_shell_access
}

module "remote_support" {
  source = "./modules/remote-support"
  count  = local.has_braintrust_support_access ? 1 : 0

  deployment_name = var.deployment_name

  database_host         = module.database.postgres_database_address
  database_secret_arn   = module.database.postgres_database_secret_arn
  redis_host            = module.redis.redis_endpoint
  redis_port            = module.redis.redis_port
  clickhouse_host       = local.clickhouse_address
  clickhouse_secret_arn = var.enable_clickhouse ? module.clickhouse[0].clickhouse_secret : null
  kms_key_arn           = local.kms_key_arn
  lambda_function_arns = [
    module.services.api_handler_arn,
    module.services.migrate_database_arn,
    module.services.ai_proxy_arn,
    module.services.catchup_etl_arn,
    module.services.quarantine_warmup_arn
  ]
  enable_braintrust_support_logs_access  = var.enable_braintrust_support_logs_access
  enable_braintrust_support_shell_access = var.enable_braintrust_support_shell_access
  vpc_id                                 = module.main_vpc.vpc_id
  private_subnet_ids                     = [module.main_vpc.private_subnet_1_id]
  public_subnet_ids                      = [module.main_vpc.public_subnet_1_id]
}

variable "enable_braintrust_support_logs_access" {
  type        = bool
  description = "Enable Cloudwatch logs access for Braintrust staff"
  default     = false
}

variable "enable_braintrust_support_shell_access" {
  type        = bool
  description = "Enable Bastion shell access for Braintrust staff. This will create a bastion host and a security group that allows EC2 instance connect access from the Braintrust IAM Role."
  default     = false
}

output "braintrust_support_role_arn" {
  description = "ARN of the Role that grants Braintrust team remote support. Share this with the Braintrust team."
  value       = local.has_braintrust_support_access ? module.remote_support[0].braintrust_support_role_arn : null
}

output "bastion_instance_id" {
  description = "Instance ID of the bastion host that Braintrust support staff can connect to using EC2 Instance Connect. Share this with the Braintrust team."
  value       = var.enable_braintrust_support_shell_access ? module.remote_support[0].bastion_instance_id : null
}

output "remote_support_security_group_id" {
  description = "Security Group ID for the Remote Support bastion host."
  value       = local.has_braintrust_support_access ? module.remote_support[0].remote_support_security_group_id : null
}
