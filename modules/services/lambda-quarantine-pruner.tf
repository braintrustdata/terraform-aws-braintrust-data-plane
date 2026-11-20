locals {
  quarantine_pruner_base_function_name = "QuarantinePrunerFunction"
  quarantine_pruner_function_name      = "${var.deployment_name}-${local.quarantine_pruner_base_function_name}"
  quarantine_pruner_function_arn       = "${local.lambda_function_arn_base}${local.quarantine_pruner_function_name}"
  quarantine_pruner_original_handler   = "index.handler"
}

# Deletes unreferenced versions of quarantine functions created by the warmup
# and API handler outside Terraform state. QUARANTINE_PRUNER_MODE gates deletion.
resource "aws_lambda_function" "quarantine_pruner" {
  count = var.enable_quarantine_pruner ? 1 : 0

  depends_on = [aws_lambda_invocation.invoke_database_migration]

  function_name = local.quarantine_pruner_function_name
  s3_bucket     = local.lambda_s3_bucket
  s3_key        = local.lambda_versions[local.quarantine_pruner_base_function_name]
  role          = var.quarantine_pruner_role_arn
  handler       = local.observability_enabled ? local.nodejs_datadog_handler : local.quarantine_pruner_original_handler
  runtime       = "nodejs22.x"
  memory_size   = 1024
  timeout       = 900
  architectures = ["arm64"]
  kms_key_arn   = var.kms_key_arn

  layers = local.observability_enabled ? [local.datadog_node_layer_arn, local.datadog_extension_arm_layer_arn] : []

  environment {
    variables = merge({
      PG_URL                        = local.postgres_url
      REDIS_URL                     = local.redis_url
      QUARANTINE_PUB_PRIVATE_VPC_ID = var.quarantine_vpc_id
      QUARANTINE_PRUNER_MODE        = var.quarantine_pruner_mode
      },
      var.extra_env_vars.QuarantinePrunerFunction,
      local.observability_enabled ? merge(local.datadog_env_vars, {
        DD_SERVICE        = local.quarantine_pruner_base_function_name
        DD_LAMBDA_HANDLER = local.quarantine_pruner_original_handler
      }) : {}
    )
  }

  logging_config {
    log_format = local.observability_enabled ? "JSON" : "Text"
    log_group  = "/braintrust/${var.deployment_name}/${local.quarantine_pruner_function_name}"
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

# The schedule stays enabled in every mode; the handler returns early when mode
# is off.
resource "aws_scheduler_schedule" "quarantine_pruner" {
  count = var.enable_quarantine_pruner ? 1 : 0

  name        = "${var.deployment_name}-quarantine-pruner-schedule"
  group_name  = aws_scheduler_schedule_group.scheduled_jobs.name
  description = "Trigger quarantine pruner Lambda function."

  schedule_expression          = "rate(1 hour)"
  schedule_expression_timezone = "UTC"
  state                        = "ENABLED"

  flexible_time_window {
    mode = "OFF"
  }

  target {
    arn      = local.quarantine_pruner_function_arn
    role_arn = var.quarantine_pruner_schedule_role_arn
    input    = local.scheduled_event_input

    retry_policy {
      maximum_event_age_in_seconds = 86400
      maximum_retry_attempts       = 185
    }
  }
}
