module "kms" {
  source = "./modules/kms"
  count  = var.kms_key_arn == "" ? 1 : 0

  deployment_name         = var.deployment_name
  additional_key_policies = var.additional_kms_key_policies
  custom_tags             = var.custom_tags
}

locals {
  kms_key_arn = var.kms_key_arn != "" ? var.kms_key_arn : module.kms[0].key_arn
  bastion_security_group = var.enable_braintrust_support_shell_access ? {
    "Remote Support Bastion" = module.remote_support[0].remote_support_security_group_id
  } : {}
  instance_connect_endpoint_security_group = var.enable_braintrust_support_shell_access ? {
    "EC2 Instance Connect Endpoint" = module.remote_support[0].instance_connect_endpoint_security_group_id
  } : {}

  # VPC configuration - handle both created and existing VPCs
  main_vpc_id                  = var.create_vpc ? module.main_vpc[0].vpc_id : var.existing_vpc_id
  main_vpc_private_subnet_1_id = var.create_vpc ? module.main_vpc[0].private_subnet_1_id : var.existing_private_subnet_1_id
  main_vpc_private_subnet_2_id = var.create_vpc ? module.main_vpc[0].private_subnet_2_id : var.existing_private_subnet_2_id
  main_vpc_private_subnet_3_id = var.create_vpc ? module.main_vpc[0].private_subnet_3_id : var.existing_private_subnet_3_id
  main_vpc_public_subnet_1_id  = var.create_vpc ? module.main_vpc[0].public_subnet_1_id : var.existing_public_subnet_1_id

  # Quarantine VPC configuration - handle both created and existing VPCs
  create_quarantine_vpc              = var.enable_quarantine_vpc && var.existing_quarantine_vpc_id == null
  quarantine_vpc_id                  = var.enable_quarantine_vpc ? (var.existing_quarantine_vpc_id != null ? var.existing_quarantine_vpc_id : module.quarantine_vpc[0].vpc_id) : null
  quarantine_vpc_private_subnet_1_id = var.enable_quarantine_vpc ? (var.existing_quarantine_vpc_id != null ? var.existing_quarantine_private_subnet_1_id : module.quarantine_vpc[0].private_subnet_1_id) : null
  quarantine_vpc_private_subnet_2_id = var.enable_quarantine_vpc ? (var.existing_quarantine_vpc_id != null ? var.existing_quarantine_private_subnet_2_id : module.quarantine_vpc[0].private_subnet_2_id) : null
  quarantine_vpc_private_subnet_3_id = var.enable_quarantine_vpc ? (var.existing_quarantine_vpc_id != null ? var.existing_quarantine_private_subnet_3_id : module.quarantine_vpc[0].private_subnet_3_id) : null

  # Database subnet configuration - use custom subnets if provided, otherwise use main VPC private subnets
  database_subnet_ids = var.database_subnet_ids != null ? var.database_subnet_ids : [
    local.main_vpc_private_subnet_1_id,
    local.main_vpc_private_subnet_2_id,
    local.main_vpc_private_subnet_3_id
  ]

  create_ecs_api                             = !var.use_deployment_mode_external_eks
  enable_ecs_api                             = local.create_ecs_api && var.enable_ecs_api
  create_ai_gateway                          = var.create_ai_gateway
  enable_ai_gateway                          = local.create_ai_gateway && var.enable_ai_gateway
  enable_internal_observability              = trimspace(nonsensitive(var.internal_observability_api_key)) != ""
  create_internal_observability_secret       = local.enable_internal_observability && (local.create_ecs_api || local.create_ai_gateway)
  ai_proxy_url_ssm_parameter_name            = "/braintrust/${var.deployment_name}/ai-proxy-url"
  api_ecs_url_ssm_parameter_name             = "/braintrust/${var.deployment_name}/ecs-api-url"
  brainstore_ai_proxy_url_ssm_parameter_name = local.enable_ecs_api ? local.api_ecs_url_ssm_parameter_name : local.ai_proxy_url_ssm_parameter_name

  # SSM parameter selector passed to Brainstore. ECS mode pins to a specific
  # version ("<name>:<version>") so a URL change (e.g. HTTP -> HTTPS) bumps the
  # version, changes the launch template, and triggers a rolling instance
  # refresh. Lambda mode passes just the bare name. one() keeps this
  # index-safe when api_ecs is absent.
  brainstore_ai_proxy_url_ssm_parameter = (
    local.enable_ecs_api
    ? "${local.brainstore_ai_proxy_url_ssm_parameter_name}:${one(module.api_ecs[*].url_ssm_parameter_version)}"
    : local.brainstore_ai_proxy_url_ssm_parameter_name
  )

  # When the ECS API is active, quarantine / in-VPC callers use the global AI
  # gateway origin for proxy traffic instead of the AI Proxy Lambda. one() keeps
  # this index-safe when services is absent (use_deployment_mode_external_eks).
  api_ecs_ai_proxy_url = local.enable_ecs_api ? "https://${trimsuffix(replace(var.global_ai_gateway_origin_domain, "/^https?:\\/\\//", ""), "/")}/v1/proxy" : one(module.services[*].ai_proxy_url)
  gateway_env_vars = local.enable_ai_gateway ? {
    GATEWAY_URL = module.gateway_alb[0].gateway_url
  } : {}
  # Only wire GATEWAY_URL into Lambdas that call the gateway. Do not merge into
  # MigrateDatabaseFunction or crons — that changes their env hash and re-runs
  # migrations or replaces unrelated functions on existing deployments.
  gateway_lambda_env_services = toset(["APIHandler", "AIProxy"])
  main_vpc_private_subnet_ids = [
    local.main_vpc_private_subnet_1_id,
    local.main_vpc_private_subnet_2_id,
    local.main_vpc_private_subnet_3_id,
  ]
  enable_private_ai_gateway_origin = local.create_ai_gateway && var.use_private_ai_gateway_origin
  service_extra_env_vars = merge(
    var.service_extra_env_vars,
    { for svc in local.gateway_lambda_env_services : svc => merge(
      lookup(var.service_extra_env_vars, svc, {}),
      local.gateway_env_vars,
    ) }
  )
}

module "main_vpc" {
  source = "./modules/vpc"
  count  = var.create_vpc ? 1 : 0

  deployment_name = var.deployment_name
  vpc_name        = "main"
  vpc_cidr        = var.vpc_cidr

  public_subnet_1_cidr      = cidrsubnet(var.vpc_cidr, 3, 0)
  public_subnet_1_az        = local.public_subnet_1_az
  private_subnet_1_cidr     = cidrsubnet(var.vpc_cidr, 3, 1)
  private_subnet_1_az       = local.private_subnet_1_az
  private_subnet_2_cidr     = cidrsubnet(var.vpc_cidr, 3, 2)
  private_subnet_2_az       = local.private_subnet_2_az
  private_subnet_3_cidr     = cidrsubnet(var.vpc_cidr, 3, 3)
  private_subnet_3_az       = local.private_subnet_3_az
  enable_brainstore_ec2_ssm = var.enable_brainstore_ec2_ssm
  custom_tags               = var.custom_tags
}

module "quarantine_vpc" {
  source = "./modules/vpc"
  count  = local.create_quarantine_vpc ? 1 : 0

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
  custom_tags           = var.custom_tags
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
  backup_retention_period            = var.postgres_backup_retention_period
  DANGER_disable_deletion_protection = var.DANGER_disable_database_deletion_protection

  kms_key_arn              = local.kms_key_arn
  permissions_boundary_arn = var.permissions_boundary_arn
  custom_tags              = var.custom_tags
}

module "redis" {
  source = "./modules/elasticache"

  deployment_name = var.deployment_name
  subnet_ids = [
    local.main_vpc_private_subnet_1_id,
    local.main_vpc_private_subnet_2_id,
    local.main_vpc_private_subnet_3_id
  ]
  vpc_id      = local.main_vpc_id
  kms_key_arn = local.kms_key_arn
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
  custom_tags         = var.custom_tags
}

module "storage" {
  source = "./modules/storage"

  deployment_name                                = var.deployment_name
  kms_key_arn                                    = local.kms_key_arn
  brainstore_s3_bucket_retention_days            = var.brainstore_s3_bucket_retention_days
  s3_additional_allowed_origins                  = var.s3_additional_allowed_origins
  s3_code_bundle_additional_allowed_origins      = var.s3_code_bundle_additional_allowed_origins
  s3_lambda_responses_additional_allowed_origins = var.s3_lambda_responses_additional_allowed_origins
  enable_s3_bucket_abac                          = var.enable_s3_bucket_abac
  custom_tags                                    = var.custom_tags
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

  brainstore_enabled              = var.enable_brainstore
  brainstore_default              = var.brainstore_default
  brainstore_hostname             = var.enable_brainstore ? module.brainstore[0].dns_name : null
  brainstore_writer_hostname      = var.enable_brainstore && var.brainstore_writer_instance_count > 0 ? module.brainstore[0].writer_dns_name : null
  brainstore_fast_reader_hostname = var.enable_brainstore && var.brainstore_fast_reader_instance_count > 0 ? module.brainstore[0].fast_reader_dns_name : null
  brainstore_s3_bucket_name       = var.enable_brainstore ? module.storage.brainstore_bucket_id : null
  brainstore_port                 = var.enable_brainstore ? module.brainstore[0].port : null
  brainstore_etl_batch_size       = var.brainstore_etl_batch_size
  brainstore_wal_footer_version   = var.brainstore_wal_footer_version
  skip_pg_for_brainstore_objects  = var.skip_pg_for_brainstore_objects
  brainstore_enable_export        = var.brainstore_enable_export

  # Storage
  code_bundle_bucket_arn      = module.storage.code_bundle_bucket_arn
  lambda_responses_bucket_arn = module.storage.lambda_responses_bucket_arn

  # Service configuration
  braintrust_org_name                        = var.braintrust_org_name
  primary_org_name                           = var.primary_org_name
  allowed_org_ids                            = var.allowed_org_ids
  btql_audit_logs_strict_org_ids             = var.btql_audit_logs_strict_org_ids
  btql_audit_logs_best_effort_org_ids        = var.btql_audit_logs_best_effort_org_ids
  api_handler_provisioned_concurrency        = var.api_handler_provisioned_concurrency
  api_handler_reserved_concurrent_executions = var.api_handler_reserved_concurrent_executions
  api_handler_memory_limit                   = var.api_handler_memory_limit
  ai_proxy_reserved_concurrent_executions    = var.ai_proxy_reserved_concurrent_executions
  ai_proxy_memory_limit                      = var.ai_proxy_memory_limit
  whitelisted_origins                        = var.whitelisted_origins
  outbound_rate_limit_window_minutes         = var.outbound_rate_limit_window_minutes
  outbound_rate_limit_max_requests           = var.outbound_rate_limit_max_requests
  unsafe_url_request_mode                    = var.unsafe_url_request_mode
  url_security_dns_servers                   = var.url_security_dns_servers
  url_security_allow_cidrs                   = var.url_security_allow_cidrs
  extra_env_vars                             = local.service_extra_env_vars

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
  quarantine_vpc_id  = local.quarantine_vpc_id
  quarantine_vpc_private_subnets = var.enable_quarantine_vpc ? [
    local.quarantine_vpc_private_subnet_1_id,
    local.quarantine_vpc_private_subnet_2_id,
    local.quarantine_vpc_private_subnet_3_id
  ] : []

  kms_key_arn                         = local.kms_key_arn
  permissions_boundary_arn            = var.permissions_boundary_arn
  api_handler_role_arn                = module.services_common.api_handler_role_arn
  api_security_group_id               = module.services_common.api_security_group_id
  function_tools_secret_key           = module.services_common.function_tools_secret_key
  quarantine_invoke_role_arn          = module.services_common.quarantine_invoke_role_arn
  quarantine_function_role_arn        = module.services_common.quarantine_function_role_arn
  quarantine_lambda_security_group_id = module.services_common.quarantine_lambda_security_group_id
  custom_tags                         = var.custom_tags

  # Observability
  internal_observability_api_key                = var.internal_observability_api_key
  internal_observability_env_name               = var.internal_observability_env_name
  internal_observability_region                 = var.internal_observability_region
  internal_observability_trace_disabled_plugins = var.internal_observability_trace_disabled_plugins
}

module "ecs" {
  source = "./modules/ecs"
  count  = local.create_ai_gateway || local.create_ecs_api ? 1 : 0

  deployment_name    = var.deployment_name
  kms_key_arn        = local.kms_key_arn
  container_insights = var.container_insights
  custom_tags        = var.custom_tags
}

module "gateway_alb" {
  source = "./modules/gateway-alb"
  count  = local.create_ai_gateway ? 1 : 0

  deployment_name                      = var.deployment_name
  vpc_id                               = local.main_vpc_id
  private_subnet_ids                   = local.main_vpc_private_subnet_ids
  enable_cloudfront_vpc_origin_ingress = local.enable_private_ai_gateway_origin
  authorized_security_groups = merge(
    {
      "API"        = module.services_common.api_security_group_id
      "Brainstore" = module.services_common.brainstore_instance_security_group_id
    },
    var.ai_gateway_authorized_security_groups,
  )
  alb_client_keep_alive    = var.ai_gateway_alb_client_keep_alive
  alb_idle_timeout         = var.ai_gateway_alb_idle_timeout
  alb_deregistration_delay = var.ai_gateway_alb_deregistration_delay
  custom_tags              = var.custom_tags
}

module "gateway_ecs" {
  source = "./modules/gateway-ecs"
  count  = local.create_ai_gateway ? 1 : 0

  deployment_name    = var.deployment_name
  kms_key_arn        = local.kms_key_arn
  vpc_id             = local.main_vpc_id
  private_subnet_ids = local.main_vpc_private_subnet_ids
  ecs_cluster_arn    = module.ecs[0].cluster_arn
  ecs_cluster_name   = module.ecs[0].cluster_name
  container_image = format(
    "public.ecr.aws/braintrust/gateway:%s",
    var.ai_gateway_version_override == null ? "prerelease" : var.ai_gateway_version_override
  )
  cpu                       = var.ai_gateway_cpu
  memory                    = var.ai_gateway_memory
  cpu_architecture          = var.ai_gateway_cpu_architecture
  min_capacity              = var.ai_gateway_min_capacity
  max_capacity              = var.ai_gateway_max_capacity
  target_cpu_utilization    = var.ai_gateway_target_cpu_utilization
  target_memory_utilization = var.ai_gateway_target_memory_utilization
  log_retention_days        = var.ai_gateway_log_retention_days
  permissions_boundary_arn  = var.permissions_boundary_arn
  redis_host                = module.redis.redis_endpoint
  redis_port                = module.redis.redis_port
  redis_security_group_id   = module.redis.redis_security_group_id
  target_group_arn          = module.gateway_alb[0].gateway_target_group_arn
  alb_security_group_id     = module.gateway_alb[0].gateway_alb_security_group_id
  gateway_http_listener_arn = module.gateway_alb[0].gateway_http_listener_arn
  extra_env_vars            = var.ai_gateway_extra_env_vars
  custom_tags               = var.custom_tags
  brainstore_license_key    = var.brainstore_license_key
  enable_execute_command    = var.ai_gateway_enable_execute_command
  braintrust_app_url        = var.ai_gateway_braintrust_app_url
  braintrust_api_url        = var.use_deployment_mode_external_eks ? var.braintrust_api_url : module.ingress[0].api_url
  unsafe_url_request_mode   = var.unsafe_url_request_mode
  url_security_dns_servers  = var.url_security_dns_servers
  url_security_allow_cidrs  = var.url_security_allow_cidrs

  # Observability
  internal_observability_api_key_secret_arn     = local.create_internal_observability_secret ? aws_secretsmanager_secret.internal_observability_api_key[0].arn : ""
  internal_observability_enabled                = local.create_internal_observability_secret
  internal_observability_env_name               = var.internal_observability_env_name
  internal_observability_region                 = var.internal_observability_region
  internal_observability_trace_disabled_plugins = var.internal_observability_trace_disabled_plugins
}

module "api_ecs" {
  source = "./modules/api-ecs"
  count  = local.create_ecs_api ? 1 : 0

  deployment_name      = var.deployment_name
  api_version_override = var.braintrust_api_version_override

  # Telemetry
  monitoring_telemetry                          = var.monitoring_telemetry
  internal_observability_api_key_secret_arn     = local.create_internal_observability_secret ? aws_secretsmanager_secret.internal_observability_api_key[0].arn : ""
  internal_observability_env_name               = var.internal_observability_env_name
  internal_observability_region                 = var.internal_observability_region
  internal_observability_trace_disabled_plugins = var.internal_observability_trace_disabled_plugins

  # Data stores
  database_url_secret_arn   = module.database.postgres_database_url_secret_arn
  redis_url_secret_arn      = module.redis.redis_url_secret_arn
  function_tools_secret_arn = module.services_common.function_tools_secret_arn

  # Brainstore
  brainstore_hostname             = module.brainstore[0].dns_name
  brainstore_writer_hostname      = var.brainstore_writer_instance_count > 0 ? module.brainstore[0].writer_dns_name : null
  brainstore_fast_reader_hostname = var.brainstore_fast_reader_instance_count > 0 ? module.brainstore[0].fast_reader_dns_name : null
  brainstore_s3_bucket_name       = module.storage.brainstore_bucket_id
  brainstore_port                 = module.brainstore[0].port
  brainstore_etl_batch_size       = var.brainstore_etl_batch_size
  brainstore_wal_footer_version   = var.brainstore_wal_footer_version
  skip_pg_for_brainstore_objects  = var.skip_pg_for_brainstore_objects
  brainstore_enable_export        = var.brainstore_enable_export

  # Storage
  code_bundle_bucket = module.storage.code_bundle_bucket_id
  response_bucket    = module.storage.lambda_responses_bucket_id

  # Service configuration
  braintrust_org_name                                          = var.braintrust_org_name
  primary_org_name                                             = var.primary_org_name
  allowed_org_ids                                              = var.allowed_org_ids
  btql_audit_logs_strict_org_ids                               = var.btql_audit_logs_strict_org_ids
  btql_audit_logs_best_effort_org_ids                          = var.btql_audit_logs_best_effort_org_ids
  log_retention_days                                           = var.braintrust_api_log_retention_days
  enable_execute_command                                       = var.api_ecs_enable_execute_command
  braintrust_api_cpu                                           = var.braintrust_api_cpu
  braintrust_api_memory                                        = var.braintrust_api_memory
  braintrust_api_min_count                                     = var.braintrust_api_min_count
  braintrust_api_max_count                                     = var.braintrust_api_max_count
  braintrust_api_cpu_autoscaling                               = var.braintrust_api_cpu_autoscaling
  braintrust_api_event_loop_utilization_autoscaling            = var.braintrust_api_event_loop_utilization_autoscaling
  braintrust_api_event_loop_delay_autoscaling                  = var.braintrust_api_event_loop_delay_autoscaling
  braintrust_api_ingest_cpu                                    = var.braintrust_api_ingest_cpu
  braintrust_api_ingest_memory                                 = var.braintrust_api_ingest_memory
  braintrust_api_ingest_min_count                              = var.braintrust_api_ingest_min_count
  braintrust_api_ingest_max_count                              = var.braintrust_api_ingest_max_count
  braintrust_api_ingest_cpu_autoscaling                        = var.braintrust_api_ingest_cpu_autoscaling
  braintrust_api_ingest_event_loop_utilization_autoscaling     = var.braintrust_api_ingest_event_loop_utilization_autoscaling
  braintrust_api_ingest_event_loop_delay_autoscaling           = var.braintrust_api_ingest_event_loop_delay_autoscaling
  braintrust_api_background_cpu                                = var.braintrust_api_background_cpu
  braintrust_api_background_memory                             = var.braintrust_api_background_memory
  braintrust_api_background_min_count                          = var.braintrust_api_background_min_count
  braintrust_api_background_max_count                          = var.braintrust_api_background_max_count
  braintrust_api_background_cpu_autoscaling                    = var.braintrust_api_background_cpu_autoscaling
  braintrust_api_background_event_loop_utilization_autoscaling = var.braintrust_api_background_event_loop_utilization_autoscaling
  braintrust_api_background_event_loop_delay_autoscaling       = var.braintrust_api_background_event_loop_delay_autoscaling
  whitelisted_origins                                          = var.whitelisted_origins
  outbound_rate_limit_window_minutes                           = var.outbound_rate_limit_window_minutes
  outbound_rate_limit_max_requests                             = var.outbound_rate_limit_max_requests
  disable_billing_telemetry_aggregation                        = var.disable_billing_telemetry_aggregation
  billing_telemetry_log_level                                  = var.billing_telemetry_log_level
  unsafe_url_request_mode                                      = var.unsafe_url_request_mode
  url_security_dns_servers                                     = var.url_security_dns_servers
  url_security_allow_cidrs                                     = var.url_security_allow_cidrs
  extra_env_vars                                               = merge(var.braintrust_api_extra_env_vars, local.gateway_env_vars)

  # Quarantine VPC
  use_quarantine_vpc = var.enable_quarantine_vpc
  quarantine_vpc_id  = local.quarantine_vpc_id
  quarantine_vpc_private_subnets = var.enable_quarantine_vpc ? [
    local.quarantine_vpc_private_subnet_1_id,
    local.quarantine_vpc_private_subnet_2_id,
    local.quarantine_vpc_private_subnet_3_id
  ] : []
  quarantine_invoke_role_arn          = module.services_common.quarantine_invoke_role_arn
  quarantine_function_role_arn        = module.services_common.quarantine_function_role_arn
  quarantine_lambda_security_group_id = module.services_common.quarantine_lambda_security_group_id
  quarantine_proxy_url                = local.api_ecs_ai_proxy_url

  # Networking
  vpc_id             = local.main_vpc_id
  private_subnet_ids = local.main_vpc_private_subnet_ids
  authorized_security_groups = merge(
    {
      "API"        = module.services_common.api_security_group_id
      "Brainstore" = module.services_common.brainstore_instance_security_group_id
    },
    var.braintrust_api_authorized_security_groups,
  )
  authorized_cidr_blocks = var.braintrust_api_authorized_cidr_blocks

  alb_certificate_arn = var.braintrust_api_alb_certificate_arn
  alb_custom_domain   = var.braintrust_api_alb_custom_domain

  kms_key_arn            = local.kms_key_arn
  ecs_cluster_arn        = module.ecs[0].cluster_arn
  ecs_cluster_name       = module.ecs[0].cluster_name
  task_role_arn          = module.services_common.api_handler_role_arn
  task_security_group_id = module.services_common.api_security_group_id
  custom_tags            = var.custom_tags
}

module "ingress" {
  source = "./modules/ingress"
  count  = !var.use_deployment_mode_external_eks ? 1 : 0

  deployment_name                    = var.deployment_name
  custom_domain                      = var.custom_domain
  custom_certificate_arn             = var.custom_certificate_arn
  waf_acl_id                         = var.waf_acl_id
  cloudfront_price_class             = var.cloudfront_price_class
  cloudfront_origin_read_timeout     = var.cloudfront_origin_read_timeout
  use_global_ai_proxy                = var.use_global_ai_proxy
  use_global_ai_gateway_origin       = var.use_global_ai_gateway_origin
  use_private_ai_gateway_origin      = local.enable_private_ai_gateway_origin
  global_ai_gateway_origin_domain    = var.global_ai_gateway_origin_domain
  gateway_alb_arn                    = local.enable_private_ai_gateway_origin ? module.gateway_alb[0].gateway_alb_arn : null
  gateway_alb_dns_name               = local.enable_private_ai_gateway_origin ? module.gateway_alb[0].gateway_alb_dns_name : null
  gateway_cloudfront_ingress_rule_id = local.enable_private_ai_gateway_origin ? module.gateway_alb[0].gateway_cloudfront_vpc_origin_ingress_rule_id : null
  ai_proxy_function_url              = module.services[0].ai_proxy_url
  api_handler_function_arn           = module.services[0].api_handler_arn
  enable_ecs_api                     = local.enable_ecs_api
  api_ecs_alb_arn                    = module.api_ecs[0].alb_arn
  api_ecs_alb_domain                 = module.api_ecs[0].alb_domain
  api_ecs_alb_https_enabled          = module.api_ecs[0].alb_https_enabled
  custom_tags                        = var.custom_tags
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
  brainstore_additional_policy_arns         = var.brainstore_additional_policy_arns
  brainstore_enable_export                  = var.brainstore_enable_export
  permissions_boundary_arn                  = var.permissions_boundary_arn
  eks_cluster_arn                           = var.existing_eks_cluster_arn
  eks_namespace                             = var.eks_namespace
  enable_eks_pod_identity                   = var.enable_eks_pod_identity
  enable_eks_irsa                           = var.enable_eks_irsa
  enable_ecs                                = local.create_ecs_api
  enable_brainstore_ec2_ssm                 = var.enable_brainstore_ec2_ssm
  custom_tags                               = var.custom_tags
  override_api_iam_role_trust_policy        = var.override_api_iam_role_trust_policy
  override_brainstore_iam_role_trust_policy = var.override_brainstore_iam_role_trust_policy
  enable_quarantine_vpc                     = var.enable_quarantine_vpc
  quarantine_vpc_id                         = local.quarantine_vpc_id
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
  skip_pg_for_brainstore_objects        = var.skip_pg_for_brainstore_objects
  brainstore_enable_export              = var.brainstore_enable_export
  extra_env_vars                        = var.brainstore_extra_env_vars
  extra_env_vars_writer                 = var.brainstore_extra_env_vars_writer
  writer_instance_count                 = var.brainstore_writer_instance_count
  writer_instance_type                  = var.brainstore_writer_instance_type
  fast_reader_instance_count            = var.brainstore_fast_reader_instance_count
  fast_reader_instance_type             = var.brainstore_fast_reader_instance_type
  extra_env_vars_fast_reader            = var.brainstore_extra_env_vars_fast_reader
  cache_file_size_fast_reader           = var.brainstore_cache_file_size_fast_reader
  ai_proxy_url_ssm_parameter            = local.brainstore_ai_proxy_url_ssm_parameter
  monitoring_telemetry                  = var.monitoring_telemetry
  database_host                         = module.database.postgres_database_address
  database_port                         = module.database.postgres_database_port
  database_secret_arn                   = module.database.postgres_database_secret_arn
  redis_host                            = module.redis.redis_endpoint
  redis_port                            = module.redis.redis_port
  service_token_secret_key              = module.services_common.function_tools_secret_key
  brainstore_s3_bucket_arn              = module.storage.brainstore_bucket_arn
  lambda_responses_s3_bucket_arn        = module.storage.lambda_responses_bucket_arn
  code_bundle_s3_bucket_arn             = module.storage.code_bundle_bucket_arn
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
  authorized_security_groups_ssh = merge(
    local.bastion_security_group,
    local.instance_connect_endpoint_security_group
  )

  private_subnet_ids = [
    local.main_vpc_private_subnet_1_id,
    local.main_vpc_private_subnet_2_id,
    local.main_vpc_private_subnet_3_id
  ]

  kms_key_arn                = local.kms_key_arn
  brainstore_iam_role_name   = module.services_common.brainstore_iam_role_name
  custom_tags                = var.custom_tags
  custom_post_install_script = var.brainstore_custom_post_install_script
  cache_file_size_reader     = var.brainstore_cache_file_size_reader
  cache_file_size_writer     = var.brainstore_cache_file_size_writer
  locks_s3_path              = var.brainstore_locks_s3_path
}
