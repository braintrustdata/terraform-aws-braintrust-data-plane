locals {
  automation_cron_function_name = "${var.deployment_name}-AutomationCron"
}

resource "aws_lambda_function" "automation_cron" {
  depends_on = [aws_lambda_invocation.invoke_database_migration]

  function_name = local.automation_cron_function_name
  s3_bucket     = local.lambda_s3_bucket
  s3_key        = local.lambda_versions["AutomationCron"]
  role          = aws_iam_role.api_handler_role.arn
  handler       = "index.handler"
  runtime       = "nodejs22.x"
  timeout       = 300
  memory_size   = 2048
  architectures = ["arm64"]

  layers = [
    "arn:aws:lambda:${data.aws_region.current.region}:041475135427:layer:duckdb-nodejs-arm64:14"
  ]

  ephemeral_storage {
    size = 4096
  }

  environment {
    variables = merge({
      ORG_NAME                                   = var.braintrust_org_name
      PG_URL                                     = local.postgres_url
      REDIS_HOST                                 = var.redis_host
      REDIS_PORT                                 = var.redis_port
      REDIS_URL                                  = "redis://${var.redis_host}:${var.redis_port}"
      BRAINSTORE_ENABLED                         = var.brainstore_enabled
      BRAINSTORE_ENABLE_HISTORICAL_FULL_BACKFILL = var.brainstore_enable_historical_full_backfill
      BRAINSTORE_BACKFILL_HISTORICAL_BATCH_SIZE  = var.brainstore_etl_batch_size
      BRAINSTORE_BACKFILL_DISABLE_HISTORICAL     = var.brainstore_backfill_new_objects
      BRAINSTORE_BACKFILL_ENABLE_NONHISTORICAL   = var.brainstore_default
      BRAINSTORE_URL                             = local.brainstore_url
      BRAINSTORE_WRITER_URL                      = local.brainstore_writer_url
      BRAINSTORE_REALTIME_WAL_BUCKET             = local.brainstore_s3_bucket
      FUNCTION_SECRET_KEY                        = aws_secretsmanager_secret_version.function_tools_secret.secret_string
    }, var.extra_env_vars.AutomationCron)
  }

  logging_config {
    log_format = "Text"
    log_group  = "/braintrust/${var.deployment_name}/${local.automation_cron_function_name}"
  }

  vpc_config {
    subnet_ids         = var.service_subnet_ids
    security_group_ids = [aws_security_group.lambda.id]
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
