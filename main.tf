module "kms" {
  source = "./modules/kms"
  count  = var.kms_key_arn == "" ? 1 : 0

  deployment_name         = var.deployment_name
  additional_key_policies = var.additional_kms_key_policies
}

locals {
  kms_key_arn = var.kms_key_arn != "" ? var.kms_key_arn : module.kms[0].key_arn
  bastion_security_group = var.enable_braintrust_support_shell_access ? {
    "Remote Support Bastion" = module.remote_support[0].remote_support_security_group_id
  } : {}

  # VPC configuration - handle both created and existing VPCs
  main_vpc_id                  = var.create_vpc ? module.main_vpc[0].vpc_id : var.existing_vpc_id
  main_vpc_private_subnet_1_id = var.create_vpc ? module.main_vpc[0].private_subnet_1_id : var.existing_private_subnet_1_id
  main_vpc_private_subnet_2_id = var.create_vpc ? module.main_vpc[0].private_subnet_2_id : var.existing_private_subnet_2_id
  main_vpc_private_subnet_3_id = var.create_vpc ? module.main_vpc[0].private_subnet_3_id : var.existing_private_subnet_3_id
  main_vpc_public_subnet_1_id  = var.create_vpc ? module.main_vpc[0].public_subnet_1_id : var.existing_public_subnet_1_id

  # Database subnet configuration - use custom subnets if provided, otherwise use main VPC private subnets
  database_subnet_ids = var.database_subnet_ids != null ? var.database_subnet_ids : [
    local.main_vpc_private_subnet_1_id,
    local.main_vpc_private_subnet_2_id,
    local.main_vpc_private_subnet_3_id
  ]
}

module "main_vpc" {
  source = "./modules/vpc"
  count  = var.create_vpc ? 1 : 0

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

  enable_brainstore_ec2_ssm = var.enable_brainstore_ec2_ssm
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
  source                              = "./modules/database"
  deployment_name                     = var.deployment_name
  postgres_instance_type              = var.postgres_instance_type
  multi_az                            = var.postgres_multi_az
  postgres_storage_size               = var.postgres_storage_size
  postgres_max_storage_size           = var.postgres_max_storage_size
  postgres_storage_type               = var.postgres_storage_type
  postgres_version                    = var.postgres_version
  database_subnet_ids                 = local.database_subnet_ids
  existing_database_subnet_group_name = var.existing_database_subnet_group_name
  vpc_id                              = local.main_vpc_id
  authorized_security_groups = merge(
    merge(
      {
        "API"        = module.services_common.api_security_group_id
        "Brainstore" = module.services_common.brainstore_instance_security_group_id
      },
      var.database_authorized_security_groups,
      # This is a deprecated security group that will be removed in the future
      !var.use_deployment_mode_external_eks ? { "Lambda Services" = module.services[0].lambda_security_group_id } : {}
    ),
    local.bastion_security_group,
  )
  postgres_storage_iops              = var.postgres_storage_iops
  postgres_storage_throughput        = var.postgres_storage_throughput
  auto_minor_version_upgrade         = var.postgres_auto_minor_version_upgrade
  DANGER_disable_deletion_protection = var.DANGER_disable_database_deletion_protection

  kms_key_arn              = local.kms_key_arn
  permissions_boundary_arn = var.permissions_boundary_arn
}

module "redis" {
  source = "./modules/elasticache"

  deployment_name = var.deployment_name
  subnet_ids = [
    local.main_vpc_private_subnet_1_id,
    local.main_vpc_private_subnet_2_id,
    local.main_vpc_private_subnet_3_id
  ]
  vpc_id = local.main_vpc_id
  authorized_security_groups = merge(
    merge(
      {
        "API"        = module.services_common.api_security_group_id
        "Brainstore" = module.services_common.brainstore_instance_security_group_id
      },
      var.redis_authorized_security_groups,
      # This is a deprecated security group that will be removed in the future
      !var.use_deployment_mode_external_eks ? { "Lambda Services" = module.services[0].lambda_security_group_id } : {}
    ),
    local.bastion_security_group,
  )
  redis_instance_type = var.redis_instance_type
  redis_version       = var.redis_version
}

module "storage" {
  source = "./modules/storage"

  deployment_name                     = var.deployment_name
  kms_key_arn                         = local.kms_key_arn
  brainstore_s3_bucket_retention_days = var.brainstore_s3_bucket_retention_days
  s3_additional_allowed_origins       = var.s3_additional_allowed_origins
}

module "services" {
  source = "./modules/services"
  count  = !var.use_deployment_mode_external_eks ? 1 : 0

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

  clickhouse_host   = null
  clickhouse_secret = null

  brainstore_enabled         = var.enable_brainstore
  brainstore_default         = var.brainstore_default
  brainstore_hostname        = var.enable_brainstore ? module.brainstore[0].dns_name : null
  brainstore_writer_hostname = var.enable_brainstore && var.brainstore_writer_instance_count > 0 ? module.brainstore[0].writer_dns_name : null
  brainstore_s3_bucket_name  = var.enable_brainstore ? module.storage.brainstore_bucket_id : null
  brainstore_port            = var.enable_brainstore ? module.brainstore[0].port : null
  brainstore_etl_batch_size  = var.brainstore_etl_batch_size

  # Storage
  code_bundle_bucket_arn      = module.storage.code_bundle_bucket_arn
  lambda_responses_bucket_arn = module.storage.lambda_responses_bucket_arn

  # Service configuration
  braintrust_org_name                        = var.braintrust_org_name
  api_handler_provisioned_concurrency        = var.api_handler_provisioned_concurrency
  api_handler_reserved_concurrent_executions = var.api_handler_reserved_concurrent_executions
  ai_proxy_reserved_concurrent_executions    = var.ai_proxy_reserved_concurrent_executions
  whitelisted_origins                        = var.whitelisted_origins
  outbound_rate_limit_window_minutes         = var.outbound_rate_limit_window_minutes
  outbound_rate_limit_max_requests           = var.outbound_rate_limit_max_requests
  extra_env_vars                             = var.service_extra_env_vars

  # Billing usage telemetry
  disable_billing_telemetry_aggregation = var.disable_billing_telemetry_aggregation
  billing_telemetry_log_level           = var.billing_telemetry_log_level

  # Networking
  vpc_id = local.main_vpc_id
  service_subnet_ids = [
    local.main_vpc_private_subnet_1_id,
    local.main_vpc_private_subnet_2_id,
    local.main_vpc_private_subnet_3_id
  ]

  # Quarantine VPC
  use_quarantine_vpc = var.enable_quarantine_vpc
  quarantine_vpc_id  = var.enable_quarantine_vpc ? module.quarantine_vpc[0].vpc_id : null
  quarantine_vpc_private_subnets = var.enable_quarantine_vpc ? [
    module.quarantine_vpc[0].private_subnet_1_id,
    module.quarantine_vpc[0].private_subnet_2_id,
    module.quarantine_vpc[0].private_subnet_3_id
  ] : []

  kms_key_arn               = local.kms_key_arn
  permissions_boundary_arn  = var.permissions_boundary_arn
  api_handler_role_arn      = module.services_common.api_handler_role_arn
  api_security_group_id     = module.services_common.api_security_group_id
  function_tools_secret_key = module.services_common.function_tools_secret_key
}

module "ingress" {
  source = "./modules/ingress"
  count  = !var.use_deployment_mode_external_eks ? 1 : 0

  deployment_name          = var.deployment_name
  custom_domain            = var.custom_domain
  custom_certificate_arn   = var.custom_certificate_arn
  use_global_ai_proxy      = var.use_global_ai_proxy
  ai_proxy_function_url    = module.services[0].ai_proxy_url
  api_handler_function_arn = module.services[0].api_handler_arn
}

module "services_common" {
  source = "./modules/services-common"

  deployment_name                           = var.deployment_name
  vpc_id                                    = local.main_vpc_id
  kms_key_arn                               = local.kms_key_arn
  database_secret_arn                       = module.database.postgres_database_secret_arn
  brainstore_s3_bucket_arn                  = module.storage.brainstore_bucket_arn
  code_bundle_s3_bucket_arn                 = module.storage.code_bundle_bucket_arn
  lambda_responses_s3_bucket_arn            = module.storage.lambda_responses_bucket_arn
  service_additional_policy_arns            = var.service_additional_policy_arns
  permissions_boundary_arn                  = var.permissions_boundary_arn
  eks_cluster_arn                           = var.existing_eks_cluster_arn
  eks_namespace                             = var.eks_namespace
  enable_eks_pod_identity                   = var.enable_eks_pod_identity
  enable_eks_irsa                           = var.enable_eks_irsa
  enable_brainstore_ec2_ssm                 = var.enable_brainstore_ec2_ssm
  override_api_iam_role_trust_policy        = var.override_api_iam_role_trust_policy
  override_brainstore_iam_role_trust_policy = var.override_brainstore_iam_role_trust_policy
}

module "brainstore" {
  source = "./modules/brainstore-ec2"
  count  = var.enable_brainstore && !var.use_deployment_mode_external_eks ? 1 : 0

  deployment_name                       = var.deployment_name
  instance_count                        = var.brainstore_instance_count
  instance_type                         = var.brainstore_instance_type
  instance_key_pair_name                = var.brainstore_instance_key_pair_name
  port                                  = var.brainstore_port
  license_key                           = var.brainstore_license_key
  version_override                      = var.brainstore_version_override
  brainstore_enable_retention           = var.brainstore_enable_retention
  extra_env_vars                        = var.brainstore_extra_env_vars
  extra_env_vars_writer                 = var.brainstore_extra_env_vars_writer
  writer_instance_count                 = var.brainstore_writer_instance_count
  writer_instance_type                  = var.brainstore_writer_instance_type
  monitoring_telemetry                  = var.monitoring_telemetry
  database_host                         = module.database.postgres_database_address
  database_port                         = module.database.postgres_database_port
  database_secret_arn                   = module.database.postgres_database_secret_arn
  redis_host                            = module.redis.redis_endpoint
  redis_port                            = module.redis.redis_port
  service_token_secret_key              = module.services_common.function_tools_secret_key
  brainstore_s3_bucket_arn              = module.storage.brainstore_bucket_arn
  internal_observability_api_key        = var.internal_observability_api_key
  internal_observability_env_name       = var.internal_observability_env_name
  internal_observability_region         = var.internal_observability_region
  brainstore_instance_security_group_id = module.services_common.brainstore_instance_security_group_id
  vpc_id                                = local.main_vpc_id
  authorized_security_groups = merge(
    merge(
      {
        "API" = module.services_common.api_security_group_id
      },
      # This is a deprecated security group that will be removed in the future
      !var.use_deployment_mode_external_eks ? { "Lambda Services" = module.services[0].lambda_security_group_id } : {}
    ),
    local.bastion_security_group
  )
  authorized_security_groups_ssh = local.bastion_security_group

  private_subnet_ids = [
    local.main_vpc_private_subnet_1_id,
    local.main_vpc_private_subnet_2_id,
    local.main_vpc_private_subnet_3_id
  ]

  kms_key_arn                = local.kms_key_arn
  brainstore_iam_role_name   = module.services_common.brainstore_iam_role_name
  custom_post_install_script = var.brainstore_custom_post_install_script
}


