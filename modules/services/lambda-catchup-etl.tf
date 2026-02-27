locals {
  catchup_etl_base_function_name = "CatchupETL"
  catchup_etl_function_name      = "${var.deployment_name}-${local.catchup_etl_base_function_name}"
  catchup_etl_original_handler   = "index.handler"
}

resource "aws_cloudwatch_log_group" "catchup_etl" {
  name              = "/braintrust/${var.deployment_name}/${local.catchup_etl_function_name}"
  retention_in_days = 90
  kms_key_id        = var.kms_key_arn

  tags = local.common_tags
}

resource "aws_lambda_function" "catchup_etl" {
  depends_on = [
    aws_lambda_invocation.invoke_database_migration,
    aws_cloudwatch_log_group.catchup_etl
  ]

  function_name = local.catchup_etl_function_name
  s3_bucket     = local.lambda_s3_bucket
  s3_key        = local.lambda_versions[local.catchup_etl_base_function_name]
  role          = aws_iam_role.default_role.arn
  handler       = local.observability_enabled ? local.nodejs_datadog_handler : local.catchup_etl_original_handler
  runtime       = "nodejs22.x"
  memory_size   = 1024
  timeout       = 900
  architectures = ["arm64"]
  kms_key_arn   = var.kms_key_arn

  layers = local.observability_enabled ? [local.datadog_node_layer_arn, local.datadog_extension_arm_layer_arn] : []

  environment {
    variables = merge({
      ORG_NAME                                  = var.braintrust_org_name
      PG_URL                                    = local.postgres_url
      REDIS_HOST                                = var.redis_host
      REDIS_PORT                                = var.redis_port
      BRAINSTORE_ENABLED                        = var.brainstore_enabled
      BRAINSTORE_URL                            = local.brainstore_url
      BRAINSTORE_WRITER_URL                     = local.brainstore_writer_url
      BRAINSTORE_REALTIME_WAL_BUCKET            = local.brainstore_s3_bucket
      BRAINSTORE_BACKFILL_HISTORICAL_BATCH_SIZE = var.brainstore_etl_batch_size
      },
      var.extra_env_vars.CatchupETL,
      local.observability_enabled ? merge(local.datadog_env_vars, {
        DD_SERVICE        = local.catchup_etl_base_function_name
        DD_LAMBDA_HANDLER = local.catchup_etl_original_handler
      }) : {}
    )
  }

  logging_config {
    log_format = local.observability_enabled ? "JSON" : "Text"
    log_group  = "/braintrust/${var.deployment_name}/${local.catchup_etl_function_name}"
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

resource "aws_cloudwatch_event_rule" "catchup_etl_schedule" {
  name                = "${var.deployment_name}-catchup-etl-schedule"
  description         = "Schedule for Braintrust Catchup ETL Lambda function"
  schedule_expression = "rate(10 minutes)"
  tags                = local.common_tags
}

resource "aws_cloudwatch_event_target" "catchup_etl_target" {
  rule      = aws_cloudwatch_event_rule.catchup_etl_schedule.name
  target_id = "BraintrustCatchupETLFunction"
  arn       = aws_lambda_function.catchup_etl.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.catchup_etl.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.catchup_etl_schedule.arn
}
