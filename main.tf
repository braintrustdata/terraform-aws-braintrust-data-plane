module "kms" {
  source = "./modules/kms"
  count  = var.kms_key_arn == "" ? 1 : 0

  deployment_name         = var.deployment_name
  additional_key_policies = var.additional_kms_key_policies
}

locals {
  kms_key_arn = var.kms_key_arn != "" ? var.kms_key_arn : module.kms[0].key_arn
  clickhouse_address = var.use_external_clickhouse_address != null ? var.use_external_clickhouse_address : (
    var.enable_clickhouse ? module.clickhouse[0].clickhouse_instance_private_ip : null
  )
  bastion_security_group = var.enable_braintrust_support_shell_access ? {
    "Remote Support Bastion" = module.remote_support[0].remote_support_security_group_id
  } : {}
}

module "main_vpc" {
  source = "./modules/vpc"

  deployment_name = var.deployment_name
  vpc_name        = "main"
  vpc_cidr        = var.vpc_cidr

  public_subnet_1_cidr  = cidrsubnet(var.vpc_cidr, 3, 0)
  public_subnet_1_az    = local.public_subnet_1_az
  private_subnet_1_cidr = cidrsubnet(var.vpc_cidr, 3, 1)
  private_subnet_1_az   = local.private_subnet_1_az
  private_subnet_2_cidr = cidrsubnet(var.vpc_cidr, 3, 2)
  private_subnet_2_az   = local.private_subnet_2_az
  private_subnet_3_cidr = cidrsubnet(var.vpc_cidr, 3, 3)
  private_subnet_3_az   = local.private_subnet_3_az
}

module "quarantine_vpc" {
  source = "./modules/vpc"
  count  = var.enable_quarantine_vpc ? 1 : 0

  deployment_name = var.deployment_name
  vpc_name        = "quarantine"
  vpc_cidr        = var.quarantine_vpc_cidr

  public_subnet_1_cidr  = cidrsubnet(var.quarantine_vpc_cidr, 3, 0)
  public_subnet_1_az    = local.quarantine_public_subnet_1_az
  private_subnet_1_cidr = cidrsubnet(var.quarantine_vpc_cidr, 3, 1)
  private_subnet_1_az   = local.quarantine_private_subnet_1_az
  private_subnet_2_cidr = cidrsubnet(var.quarantine_vpc_cidr, 3, 2)
  private_subnet_2_az   = local.quarantine_private_subnet_2_az
  private_subnet_3_cidr = cidrsubnet(var.quarantine_vpc_cidr, 3, 3)
  private_subnet_3_az   = local.quarantine_private_subnet_3_az
}

module "database" {
  source                    = "./modules/database"
  deployment_name           = var.deployment_name
  postgres_instance_type    = var.postgres_instance_type
  multi_az                  = var.postgres_multi_az
  postgres_storage_size     = var.postgres_storage_size
  postgres_max_storage_size = var.postgres_max_storage_size
  postgres_storage_type     = var.postgres_storage_type
  postgres_version          = var.postgres_version
  database_subnet_ids = [
    module.main_vpc.private_subnet_1_id,
    module.main_vpc.private_subnet_2_id,
    module.main_vpc.private_subnet_3_id
  ]
  vpc_id = module.main_vpc.vpc_id
  authorized_security_groups = merge(
    {
      "Lambda Services" = module.services.lambda_security_group_id
      "Brainstore"      = var.enable_brainstore ? module.brainstore[0].brainstore_instance_security_group_id : null
    },
    local.bastion_security_group,
  )
  postgres_storage_iops       = var.postgres_storage_iops
  postgres_storage_throughput = var.postgres_storage_throughput
  auto_minor_version_upgrade  = var.postgres_auto_minor_version_upgrade

  kms_key_arn = local.kms_key_arn
}

module "redis" {
  source = "./modules/elasticache"

  deployment_name = var.deployment_name
  subnet_ids = [
    module.main_vpc.private_subnet_1_id,
    module.main_vpc.private_subnet_2_id,
    module.main_vpc.private_subnet_3_id
  ]
  vpc_id = module.main_vpc.vpc_id
  authorized_security_groups = merge(
    {
      "Lambda Services" = module.services.lambda_security_group_id
      "Brainstore"      = var.enable_brainstore ? module.brainstore[0].brainstore_instance_security_group_id : null
    },
    local.bastion_security_group,
  )
  redis_instance_type = var.redis_instance_type
  redis_version       = var.redis_version
}

module "services" {
  source = "./modules/services"

  deployment_name             = var.deployment_name
  lambda_version_tag_override = var.lambda_version_tag_override

  # Telemetry
  monitoring_telemetry = var.monitoring_telemetry

  # Data stores
  postgres_username = module.database.postgres_database_username
  postgres_password = module.database.postgres_database_password
  postgres_host     = module.database.postgres_database_address
  postgres_port     = module.database.postgres_database_port
  redis_host        = module.redis.redis_endpoint
  redis_port        = module.redis.redis_port

  clickhouse_host   = local.clickhouse_address
  clickhouse_secret = var.enable_clickhouse ? module.clickhouse[0].clickhouse_secret : null

  brainstore_enabled                         = var.enable_brainstore
  brainstore_default                         = var.brainstore_default
  brainstore_hostname                        = var.enable_brainstore ? module.brainstore[0].dns_name : null
  brainstore_writer_hostname                 = var.enable_brainstore && var.brainstore_writer_instance_count > 0 ? module.brainstore[0].writer_dns_name : null
  brainstore_s3_bucket_name                  = var.enable_brainstore ? module.brainstore[0].s3_bucket : null
  brainstore_port                            = var.enable_brainstore ? module.brainstore[0].port : null
  brainstore_enable_historical_full_backfill = var.brainstore_enable_historical_full_backfill
  brainstore_backfill_new_objects            = var.brainstore_backfill_new_objects
  brainstore_etl_batch_size                  = var.brainstore_etl_batch_size

  # Service configuration
  braintrust_org_name                        = var.braintrust_org_name
  api_handler_provisioned_concurrency        = var.api_handler_provisioned_concurrency
  api_handler_reserved_concurrent_executions = var.api_handler_reserved_concurrent_executions
  ai_proxy_reserved_concurrent_executions    = var.ai_proxy_reserved_concurrent_executions
  whitelisted_origins                        = var.whitelisted_origins
  s3_additional_allowed_origins              = var.s3_additional_allowed_origins
  outbound_rate_limit_window_minutes         = var.outbound_rate_limit_window_minutes
  outbound_rate_limit_max_requests           = var.outbound_rate_limit_max_requests
  custom_domain                              = var.custom_domain
  custom_certificate_arn                     = var.custom_certificate_arn
  service_additional_policy_arns             = var.service_additional_policy_arns
  extra_env_vars                             = var.service_extra_env_vars

  # Billing usage telemetry
  disable_billing_telemetry_aggregation = var.disable_billing_telemetry_aggregation
  billing_telemetry_log_level           = var.billing_telemetry_log_level

  # Networking
  vpc_id = module.main_vpc.vpc_id
  service_subnet_ids = [
    module.main_vpc.private_subnet_1_id,
    module.main_vpc.private_subnet_2_id,
    module.main_vpc.private_subnet_3_id
  ]

  # Quarantine VPC
  use_quarantine_vpc = var.enable_quarantine_vpc
  quarantine_vpc_id  = var.enable_quarantine_vpc ? module.quarantine_vpc[0].vpc_id : null
  quarantine_vpc_private_subnets = var.enable_quarantine_vpc ? [
    module.quarantine_vpc[0].private_subnet_1_id,
    module.quarantine_vpc[0].private_subnet_2_id,
    module.quarantine_vpc[0].private_subnet_3_id
  ] : []

  kms_key_arn = local.kms_key_arn
}

module "clickhouse" {
  source = "./modules/clickhouse"
  count  = var.enable_clickhouse ? 1 : 0

  deployment_name                  = var.deployment_name
  clickhouse_instance_count        = var.use_external_clickhouse_address != null ? 0 : 1
  clickhouse_instance_type         = var.clickhouse_instance_type
  clickhouse_metadata_storage_size = var.clickhouse_metadata_storage_size
  clickhouse_subnet_id             = module.main_vpc.private_subnet_1_id
  clickhouse_security_group_ids    = [module.main_vpc.default_security_group_id]

  kms_key_arn = local.kms_key_arn
}

module "brainstore" {
  source = "./modules/brainstore"
  count  = var.enable_brainstore ? 1 : 0

  deployment_name             = var.deployment_name
  instance_count              = var.brainstore_instance_count
  instance_type               = var.brainstore_instance_type
  instance_key_pair_name      = var.brainstore_instance_key_pair_name
  port                        = var.brainstore_port
  license_key                 = var.brainstore_license_key
  version_override            = var.brainstore_version_override
  s3_bucket_retention_days    = var.brainstore_s3_bucket_retention_days
  brainstore_enable_retention = var.brainstore_enable_retention
  extra_env_vars              = var.brainstore_extra_env_vars
  extra_env_vars_writer       = var.brainstore_extra_env_vars_writer
  writer_instance_count       = var.brainstore_writer_instance_count
  writer_instance_type        = var.brainstore_writer_instance_type
  monitoring_telemetry        = var.monitoring_telemetry
  database_host               = module.database.postgres_database_address
  database_port               = module.database.postgres_database_port
  database_secret_arn         = module.database.postgres_database_secret_arn
  redis_host                  = module.redis.redis_endpoint
  redis_port                  = module.redis.redis_port
  service_token_secret_key    = module.services.function_tools_secret_key

  internal_observability_api_key  = var.internal_observability_api_key
  internal_observability_env_name = var.internal_observability_env_name
  internal_observability_region   = var.internal_observability_region

  intelligent_tiering_enabled = var.brainstore_intelligent_tiering_enabled
  intelligent_tiering_days   = var.brainstore_intelligent_tiering_days

  vpc_id = module.main_vpc.vpc_id
  authorized_security_groups = merge(
    {
      "Lambda Services" = module.services.lambda_security_group_id
    },
    local.bastion_security_group
  )
  authorized_security_groups_ssh = local.bastion_security_group

  private_subnet_ids = [
    module.main_vpc.private_subnet_1_id,
    module.main_vpc.private_subnet_2_id,
    module.main_vpc.private_subnet_3_id
  ]

  kms_key_arn = local.kms_key_arn
}
