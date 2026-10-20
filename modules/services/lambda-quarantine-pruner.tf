locals {
  quarantine_pruner_base_function_name = "QuarantinePrunerFunction"
  quarantine_pruner_function_name      = "${var.deployment_name}-${local.quarantine_pruner_base_function_name}"
  quarantine_pruner_original_handler   = "index.handler"
}

# Deletes unreferenced versions of quarantine functions created by the warmup
# and API handler outside Terraform state. QUARANTINE_PRUNER_MODE gates deletion.
resource "aws_lambda_function" "quarantine_pruner" {
  count = var.enable_quarantine_pruner ? 1 : 0

  depends_on = [
    aws_lambda_invocation.invoke_database_migration,
    # VPC ENI permissions must be attached before the function config is updated.
    aws_iam_role_policy_attachment.quarantine_pruner_vpc_access,
  ]

  function_name = local.quarantine_pruner_function_name
  s3_bucket     = local.lambda_s3_bucket
  s3_key        = local.lambda_versions[local.quarantine_pruner_base_function_name]
  role          = aws_iam_role.quarantine_pruner_role[0].arn
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
      REDIS_URL                     = "redis://${var.redis_host}:${var.redis_port}"
      QUARANTINE_PUB_PRIVATE_VPC_ID = var.quarantine_vpc_id
      QUARANTINE_PRUNER_MODE        = var.quarantine_pruner_mode
      },
      local.redis_extra_env_vars,
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

# The schedule stays enabled in every mode; in off mode the handler exits
# before calling AWS or Redis.
resource "aws_cloudwatch_event_rule" "quarantine_pruner_schedule" {
  count = var.enable_quarantine_pruner ? 1 : 0

  name                = "${var.deployment_name}-quarantine-pruner-schedule"
  description         = "Trigger quarantine pruner Lambda function."
  schedule_expression = "rate(1 hour)"
  state               = "ENABLED"
  tags                = local.common_tags
}

resource "aws_cloudwatch_event_target" "quarantine_pruner_target" {
  count = var.enable_quarantine_pruner ? 1 : 0

  rule      = aws_cloudwatch_event_rule.quarantine_pruner_schedule[0].name
  target_id = "QuarantinePrunerLambdaTarget"
  arn       = aws_lambda_function.quarantine_pruner[0].arn
}

resource "aws_lambda_permission" "allow_quarantine_pruner_eventbridge" {
  count = var.enable_quarantine_pruner ? 1 : 0

  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.quarantine_pruner[0].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.quarantine_pruner_schedule[0].arn
}
