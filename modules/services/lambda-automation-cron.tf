locals {
  automation_cron_function_name    = "${var.deployment_name}-AutomationCron"
  automation_cron_original_handler = "index.handler"
}

resource "aws_lambda_function" "automation_cron" {
  depends_on = [aws_lambda_invocation.invoke_database_migration]

  function_name = local.automation_cron_function_name
  s3_bucket     = local.lambda_s3_bucket
  s3_key        = local.lambda_versions["AutomationCron"]
  role          = var.api_handler_role_arn
  handler       = local.observability_enabled ? local.nodejs_datadog_handler : local.automation_cron_original_handler
  runtime       = "nodejs22.x"
  timeout       = 300
  memory_size   = 2048
  architectures = ["arm64"]

  # See https://github.com/tobilg/duckdb-nodejs-layer
  layers = concat(
    [local.duckdb_nodejs_arm64_layer_arn],
    local.observability_enabled ? [local.datadog_node_layer_arn, local.datadog_extension_arm_layer_arn] : []
  )

  ephemeral_storage {
    size = 4096
  }

  environment {
    variables = merge({
      ORG_NAME                                  = var.braintrust_org_name
      PG_URL                                    = local.postgres_url
      REDIS_HOST                                = var.redis_host
      REDIS_PORT                                = var.redis_port
      REDIS_URL                                 = "redis://${var.redis_host}:${var.redis_port}"
      BRAINSTORE_ENABLED                        = var.brainstore_enabled
      BRAINSTORE_BACKFILL_HISTORICAL_BATCH_SIZE = var.brainstore_etl_batch_size
      BRAINSTORE_BACKFILL_ENABLE_NONHISTORICAL  = var.brainstore_default
      BRAINSTORE_URL                            = local.brainstore_url
      BRAINSTORE_WRITER_URL                     = local.brainstore_writer_url
      BRAINSTORE_REALTIME_WAL_BUCKET            = local.brainstore_s3_bucket
      FUNCTION_SECRET_KEY                       = var.function_tools_secret_key
      },
      var.extra_env_vars.AutomationCron,
      local.observability_enabled ? merge(local.datadog_env_vars, {
        DD_SERVICE        = local.automation_cron_function_name
        DD_LAMBDA_HANDLER = local.automation_cron_original_handler
      }) : {}
    )
  }

  logging_config {
    log_format = local.observability_enabled ? "JSON" : "Text"
    log_group  = "/braintrust/${var.deployment_name}/${local.automation_cron_function_name}"
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

resource "aws_cloudwatch_event_rule" "automation_cron_schedule" {
  name                = "${var.deployment_name}-automation-cron-schedule"
  description         = "Trigger automation cron Lambda function."
  schedule_expression = "rate(10 minutes)"
  tags                = local.common_tags
}

resource "aws_cloudwatch_event_target" "automation_cron_target" {
  rule      = aws_cloudwatch_event_rule.automation_cron_schedule.name
  target_id = "AutomationCronLambdaTarget"
  arn       = aws_lambda_function.automation_cron.arn
}

resource "aws_lambda_permission" "allow_automation_cron_eventbridge" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.automation_cron.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.automation_cron_schedule.arn
}
