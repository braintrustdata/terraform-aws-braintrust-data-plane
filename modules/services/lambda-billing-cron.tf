locals {
  billing_cron_base_function_name = "BillingCron"
  billing_cron_function_name      = "${var.deployment_name}-${local.billing_cron_base_function_name}"
  billing_cron_original_handler   = "lambda.handler"
}


resource "aws_lambda_function" "billing_cron" {
  depends_on = [aws_lambda_invocation.invoke_database_migration]

  function_name = local.billing_cron_function_name
  s3_bucket     = local.lambda_s3_bucket
  s3_key        = local.lambda_versions[local.billing_cron_base_function_name]
  role          = aws_iam_role.default_role.arn
  handler       = local.observability_enabled ? local.nodejs_datadog_handler : local.billing_cron_original_handler
  runtime       = "nodejs22.x"
  timeout       = 300
  memory_size   = 1024
  architectures = ["arm64"]

  layers = local.observability_enabled ? [local.datadog_node_layer_arn, local.datadog_extension_arm_layer_arn] : []

  environment {
    variables = merge({
      ORG_NAME                      = var.braintrust_org_name
      PG_URL                        = local.postgres_url
      REDIS_HOST                    = var.redis_host
      REDIS_PORT                    = var.redis_port
      CONTROL_PLANE_TELEMETRY       = var.monitoring_telemetry
      TELEMETRY_DISABLE_AGGREGATION = var.disable_billing_telemetry_aggregation
      TELEMETRY_LOG_LEVEL           = var.billing_telemetry_log_level
      SERVICE_TOKEN_SECRET_KEY      = var.function_tools_secret_key
      },
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

resource "aws_cloudwatch_event_rule" "billing_cron_schedule" {

  name                = "${var.deployment_name}-billing-cron-schedule"
  description         = "Trigger billing cron Lambda function."
  schedule_expression = "rate(5 minutes)"
  tags                = local.common_tags
}

resource "aws_cloudwatch_event_target" "billing_cron_target" {
  rule      = aws_cloudwatch_event_rule.billing_cron_schedule.name
  target_id = "BillingCronLambdaTarget"
  arn       = aws_lambda_function.billing_cron.arn
}

resource "aws_lambda_permission" "allow_billing_cron_eventbridge" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.billing_cron.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.billing_cron_schedule.arn
}

# TODO: remove this after automation cron migration
resource "random_password" "service_token_secret_key" {
  length  = 32
  special = false
}
