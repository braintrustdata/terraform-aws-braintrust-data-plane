locals {
  billing_cron_base_function_name = "BillingCron"
  billing_cron_function_name      = "${var.deployment_name}-${local.billing_cron_base_function_name}"
  billing_cron_function_arn       = "${local.lambda_function_arn_base}${local.billing_cron_function_name}"
  billing_cron_original_handler   = "lambda.handler"
}


resource "aws_lambda_function" "billing_cron" {
  depends_on = [
    aws_lambda_invocation.invoke_database_migration,
    terraform_data.brainstore_deployment,
  ]

  function_name = local.billing_cron_function_name
  s3_bucket     = local.lambda_s3_bucket
  s3_key        = local.lambda_versions[local.billing_cron_base_function_name]
  role          = var.billing_cron_role_arn
  handler       = local.observability_enabled ? local.nodejs_datadog_handler : local.billing_cron_original_handler
  runtime       = "nodejs22.x"
  timeout       = 300
  memory_size   = 1024
  architectures = ["arm64"]
  kms_key_arn   = var.kms_key_arn

  layers = local.observability_enabled ? [local.datadog_node_layer_arn, local.datadog_extension_arm_layer_arn] : []

  environment {
    variables = merge({
      ORG_NAME                      = var.braintrust_org_name
      BRAINTRUST_LEGACY_IDS         = "true" # emit v3 spans in py+ts sdks. remove this setting when v4 migration is complete
      PG_URL                        = local.postgres_url
      REDIS_HOST                    = var.redis_host
      REDIS_PORT                    = var.redis_port
      CONTROL_PLANE_TELEMETRY       = var.monitoring_telemetry
      TELEMETRY_DISABLE_AGGREGATION = var.disable_billing_telemetry_aggregation
      TELEMETRY_LOG_LEVEL           = var.billing_telemetry_log_level
      SERVICE_TOKEN_SECRET_KEY      = var.function_tools_secret_key
      },
      local.redis_extra_env_vars,
      var.extra_env_vars.BillingCron,
      local.observability_enabled ? merge(local.datadog_env_vars, {
        DD_SERVICE        = local.billing_cron_base_function_name
        DD_LAMBDA_HANDLER = local.billing_cron_original_handler
      }) : {}
    )
  }

  logging_config {
    log_format = local.observability_enabled ? "JSON" : "Text"
    log_group  = "/braintrust/${var.deployment_name}/${local.billing_cron_function_name}"
  }

  vpc_config {
    subnet_ids         = var.service_subnet_ids
    security_group_ids = [var.api_security_group_id]
  }

  tracing_config {
    mode = "PassThrough"
  }

  tags = local.common_tags
}

resource "aws_scheduler_schedule" "billing_cron" {
  name        = "${var.deployment_name}-billing-cron-schedule"
  group_name  = aws_scheduler_schedule_group.scheduled_jobs.name
  description = "Trigger billing cron Lambda function."

  schedule_expression          = "rate(5 minutes)"
  schedule_expression_timezone = "UTC"

  flexible_time_window {
    mode = "OFF"
  }

  target {
    arn      = local.billing_cron_function_arn
    role_arn = var.billing_cron_schedule_role_arn
    input    = local.scheduled_event_input

    retry_policy {
      maximum_event_age_in_seconds = 86400
      maximum_retry_attempts       = 185
    }
  }
}

# TODO: remove this after automation cron migration
resource "random_password" "service_token_secret_key" {
  length  = 32
  special = false

  lifecycle {
    ignore_changes = [special]
  }
}
