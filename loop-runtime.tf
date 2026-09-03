locals {
  # Loop runtime requires the ECS API data plane and Brainstore (it reads
  # module.brainstore[0] for the reader URL / SG). It is fronted by the shared
  # CloudFront distribution at /loop/runtime*.
  create_loop_runtime = local.create_ecs_api && var.enable_loop_runtime

  loop_runtime_version = (
    var.loop_runtime_version_override != null
    ? var.loop_runtime_version_override
    : jsondecode(file("${path.module}/modules/loop-runtime-ecs/VERSIONS.json"))["loop-runtime"]
  )

  loop_runtime_brainstore_reader_url = local.create_loop_runtime ? format(
    "http://%s:%s",
    var.brainstore_fast_reader_instance_count > 0 ? module.brainstore[0].fast_reader_dns_name : module.brainstore[0].dns_name,
    module.brainstore[0].port,
  ) : ""

  # Codex app-server on the Loop ECS task is the LLM client. Exec-server in
  # the MicroVM never calls this URL. Prefer the in-VPC private gateway ALB
  # when it exists; otherwise hosted gateway or CloudFront API /v1/proxy.
  # Do not use the AI Proxy Function URL — that hop is for internet-mode /
  # quarantine callers, not Loop.
  hosted_ai_gateway_proxy_url = format(
    "https://%s/v1/proxy",
    trimsuffix(replace(var.global_ai_gateway_origin_domain, "/^https?:\\/\\//", ""), "/"),
  )
  loop_runtime_ai_proxy_url = (
    local.create_ai_gateway
    ? "${one(module.gateway_alb[*].gateway_url)}/v1/proxy"
    : (
      var.use_global_ai_gateway_origin
      ? local.hosted_ai_gateway_proxy_url
      : one(module.ingress[*].api_url)
    )
  )
}

module "loop_runtime_alb" {
  source = "./modules/loop-runtime-alb"
  count  = local.create_loop_runtime ? 1 : 0

  deployment_name                      = var.deployment_name
  vpc_id                               = local.main_vpc_id
  private_subnet_ids                   = local.main_vpc_private_subnet_ids
  enable_cloudfront_vpc_origin_ingress = true
  authorized_security_groups = {
    "API" = module.services_common.api_security_group_id
  }
  alb_deregistration_delay = var.loop_runtime_alb_deregistration_delay
  custom_tags              = local.all_custom_tags
}

module "loop_runtime_sandbox_aws_microvm" {
  source = "./modules/loop-runtime-sandbox-aws-microvm"
  count  = local.create_loop_runtime ? 1 : 0

  deployment_name          = var.deployment_name
  permissions_boundary_arn = var.permissions_boundary_arn
  microvm_version_tag      = local.loop_runtime_version

  microvm_minimum_memory_mib            = var.loop_runtime_microvm_minimum_memory_mib
  microvm_max_idle_duration_seconds     = var.loop_runtime_microvm_max_idle_duration_seconds
  microvm_suspended_duration_seconds    = var.loop_runtime_microvm_suspended_duration_seconds
  microvm_maximum_duration_seconds      = var.loop_runtime_microvm_maximum_duration_seconds
  microvm_auth_token_expiration_minutes = var.loop_runtime_microvm_auth_token_expiration_minutes
  enable_microvm_runtime_logs           = var.enable_loop_runtime_microvm_runtime_logs
  sandbox_egress_mode                   = var.loop_runtime_sandbox_egress_mode

  kms_key_arn = local.kms_key_arn
  custom_tags = local.all_custom_tags
}

module "loop_runtime_ecs" {
  source = "./modules/loop-runtime-ecs"
  count  = local.create_loop_runtime ? 1 : 0

  deployment_name    = var.deployment_name
  kms_key_arn        = local.kms_key_arn
  vpc_id             = local.main_vpc_id
  private_subnet_ids = local.main_vpc_private_subnet_ids
  ecs_cluster_arn    = module.ecs[0].cluster_arn
  ecs_cluster_name   = module.ecs[0].cluster_name

  container_image = format("public.ecr.aws/braintrust/loop-runtime:%s", local.loop_runtime_version)

  cpu                       = var.loop_runtime_task_cpu
  memory                    = var.loop_runtime_task_memory
  ephemeral_storage_gib     = var.loop_runtime_ephemeral_storage_gib
  min_capacity              = var.loop_runtime_min_capacity
  max_capacity              = var.loop_runtime_max_capacity
  target_cpu_utilization    = var.loop_runtime_target_cpu_utilization
  target_memory_utilization = var.loop_runtime_target_memory_utilization
  log_retention_days        = var.loop_runtime_log_retention_days
  permissions_boundary_arn  = var.permissions_boundary_arn
  enable_execute_command    = var.loop_runtime_enable_execute_command

  # ALB wiring
  target_group_arn               = module.loop_runtime_alb[0].loop_runtime_target_group_arn
  alb_security_group_id          = module.loop_runtime_alb[0].loop_runtime_alb_security_group_id
  loop_runtime_http_listener_arn = module.loop_runtime_alb[0].loop_runtime_http_listener_arn

  # Sandbox seam
  sandbox_env_vars                 = module.loop_runtime_sandbox_aws_microvm[0].sandbox_env_vars
  additional_task_role_policy_json = module.loop_runtime_sandbox_aws_microvm[0].task_role_policy_json

  # Data-plane connectivity
  database_url_secret_arn   = module.database.postgres_database_url_secret_arn
  redis_url_secret_arn      = module.redis.redis_url_secret_arn
  function_tools_secret_arn = module.services_common.function_tools_secret_arn

  brainstore_s3_bucket_name        = module.storage.brainstore_bucket_id
  brainstore_s3_bucket_arn         = module.storage.brainstore_bucket_arn
  brainstore_s3_bucket_kms_key_arn = var.existing_brainstore_s3_bucket_kms_key_arn
  code_bundle_bucket               = module.storage.code_bundle_bucket_id
  code_bundle_bucket_arn           = module.storage.code_bundle_bucket_arn

  brainstore_reader_url = local.loop_runtime_brainstore_reader_url
  ai_proxy_url          = local.loop_runtime_ai_proxy_url
  braintrust_api_url    = module.ingress[0].api_url

  # Shared Brainstore WAL format + lock prefix — must match the API/Brainstore writers.
  brainstore_locks_s3_path       = var.brainstore_locks_s3_path
  brainstore_wal_footer_version  = var.brainstore_wal_footer_version
  skip_pg_for_brainstore_objects = var.skip_pg_for_brainstore_objects

  brainstore_license_key = var.brainstore_license_key
  monitoring_telemetry   = var.monitoring_telemetry

  # SG ingress targets so tasks can reach Postgres / Redis / Brainstore / gateway
  database_security_group_id   = module.database.rds_security_group_id
  database_port                = module.database.postgres_database_port
  redis_security_group_id      = module.redis.redis_security_group_id
  redis_port                   = module.redis.redis_port
  brainstore_security_group_id = module.brainstore[0].brainstore_elb_security_group_id
  brainstore_port              = module.brainstore[0].port
  gateway_security_group_id    = local.create_ai_gateway ? one(module.gateway_alb[*].gateway_alb_security_group_id) : null

  # Runtime config
  org_name        = var.loop_runtime_org_name
  allowed_org_ids = var.allowed_org_ids
  extra_env_vars  = var.loop_runtime_extra_env_vars

  # Observability
  internal_observability_enabled            = local.create_internal_observability_secret
  internal_observability_api_key_secret_arn = local.create_internal_observability_secret ? aws_secretsmanager_secret.internal_observability_api_key[0].arn : ""
  internal_observability_env_name           = var.internal_observability_env_name
  internal_observability_region             = var.internal_observability_region

  custom_tags = local.all_custom_tags
}
