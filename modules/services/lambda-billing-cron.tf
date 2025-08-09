locals {
  billing_cron_function_name = "${var.deployment_name}-BillingCron"
}


resource "aws_lambda_function" "billing_cron" {

  function_name = local.billing_cron_function_name
  s3_bucket     = local.lambda_s3_bucket
  s3_key        = local.lambda_versions["BillingCron"]
  role          = aws_iam_role.default_role.arn
  handler       = "lambda.handler"
  runtime       = "nodejs22.x"
  timeout       = 300
  memory_size   = 1024
  architectures = ["arm64"]

  environment {
    variables = merge({
      ORG_NAME                      = var.braintrust_org_name
      PG_URL                        = local.postgres_url
      REDIS_HOST                    = var.redis_host
      REDIS_PORT                    = var.redis_port
      TELEMETRY_URL                 = var.billing_telemetry_url
      TELEMETRY_DISABLE_AGGREGATION = var.disable_billing_telemetry_aggregation
      TELEMETRY_LOG_LEVEL           = var.billing_telemetry_log_level
      SERVICE_TOKEN_SECRET_KEY      = random_password.service_token_secret_key.result
    }, var.extra_env_vars.BillingCron)
  }

  logging_config {
    log_format = "Text"
    log_group  = "/braintrust/${var.deployment_name}/${local.billing_cron_function_name}"
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


# TODO: automation cron / service token keys will replace this
resource "random_password" "service_token_secret_key" {
  length  = 32
  special = false
}
