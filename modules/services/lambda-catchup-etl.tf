locals {
  catchup_etl_function_name = "${var.deployment_name}-CatchupETL"
}

resource "aws_lambda_function" "catchup_etl" {
  depends_on = [aws_lambda_invocation.invoke_database_migration]

  function_name = local.catchup_etl_function_name
  s3_bucket     = local.lambda_s3_bucket
  s3_key        = local.lambda_versions["CatchupETL"]
  role          = aws_iam_role.default_role.arn
  handler       = "index.handler"
  runtime       = "nodejs22.x"
  memory_size   = 1024
  timeout       = 900
  architectures = ["arm64"]
  kms_key_arn   = var.kms_key_arn

  environment {
    variables = merge({
      ORG_NAME                                   = var.braintrust_org_name
      PG_URL                                     = local.postgres_url
      REDIS_HOST                                 = var.redis_host
      REDIS_PORT                                 = var.redis_port
      BRAINSTORE_ENABLED                         = var.brainstore_enabled
      BRAINSTORE_URL                             = local.brainstore_url
      BRAINSTORE_WRITER_URL                      = local.brainstore_writer_url
      BRAINSTORE_REALTIME_WAL_BUCKET             = local.brainstore_s3_bucket
      BRAINSTORE_ENABLE_HISTORICAL_FULL_BACKFILL = var.brainstore_enable_historical_full_backfill
      BRAINSTORE_BACKFILL_NEW_OBJECTS            = var.brainstore_backfill_new_objects
      CLICKHOUSE_ETL_BATCH_SIZE                  = var.brainstore_etl_batch_size
      CLICKHOUSE_PG_URL                          = local.clickhouse_pg_url
      CLICKHOUSE_CONNECT_URL                     = local.clickhouse_connect_url
    }, var.extra_env_vars.CatchupETL)
  }

  logging_config {
    log_format = "Text"
    log_group  = "/braintrust/${var.deployment_name}/${local.catchup_etl_function_name}"
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
