locals {
  quarantine_warmup_base_function_name = "QuarantineWarmupFunction"
  quarantine_warmup_function_name      = "${var.deployment_name}-${local.quarantine_warmup_base_function_name}"
  quarantine_warmup_original_handler   = "index.handler"
}

resource "aws_cloudwatch_log_group" "quarantine_warmup" {
  count = var.use_quarantine_vpc ? 1 : 0

  name              = "/braintrust/${var.deployment_name}/${local.quarantine_warmup_function_name}"
  retention_in_days = 90
  kms_key_id        = var.kms_key_arn

  tags = local.common_tags
}

resource "aws_lambda_function" "quarantine_warmup" {
  count = var.use_quarantine_vpc ? 1 : 0

  depends_on = [aws_lambda_invocation.invoke_database_migration]

  function_name = local.quarantine_warmup_function_name
  s3_bucket     = local.lambda_s3_bucket
  s3_key        = local.lambda_versions[local.quarantine_warmup_base_function_name]
  role          = var.api_handler_role_arn
  handler       = local.observability_enabled ? local.nodejs_datadog_handler : local.quarantine_warmup_original_handler
  runtime       = "nodejs22.x"
  memory_size   = 1024
  timeout       = 900
  architectures = ["arm64"]
  kms_key_arn   = var.kms_key_arn

  # See https://github.com/tobilg/duckdb-nodejs-layer
  layers = concat(
    [local.duckdb_nodejs_arm64_layer_arn],
    local.observability_enabled ? [local.datadog_node_layer_arn, local.datadog_extension_arm_layer_arn] : []
  )

  environment {
    variables = merge({
      ORG_NAME                   = var.braintrust_org_name
      BRAINTRUST_DEPLOYMENT_NAME = var.deployment_name

      PG_URL     = local.postgres_url
      REDIS_HOST = var.redis_host
      REDIS_PORT = var.redis_port

      QUARANTINE_INVOKE_ROLE                            = var.use_quarantine_vpc ? aws_iam_role.quarantine_invoke_role.arn : ""
      QUARANTINE_FUNCTION_ROLE                          = var.use_quarantine_vpc ? aws_iam_role.quarantine_function_role.arn : ""
      QUARANTINE_PRIVATE_SUBNET_1_ID                    = var.use_quarantine_vpc ? var.quarantine_vpc_private_subnets[0] : ""
      QUARANTINE_PRIVATE_SUBNET_2_ID                    = var.use_quarantine_vpc ? var.quarantine_vpc_private_subnets[1] : ""
      QUARANTINE_PRIVATE_SUBNET_3_ID                    = var.use_quarantine_vpc ? var.quarantine_vpc_private_subnets[2] : ""
      QUARANTINE_PUB_PRIVATE_VPC_DEFAULT_SECURITY_GROUP = var.use_quarantine_vpc ? aws_security_group.quarantine_lambda[0].id : ""
      QUARANTINE_PUB_PRIVATE_VPC_ID                     = var.use_quarantine_vpc ? var.quarantine_vpc_id : ""
      },
      var.extra_env_vars.QuarantineWarmupFunction,
      local.observability_enabled ? merge(local.datadog_env_vars, {
        DD_SERVICE        = local.quarantine_warmup_base_function_name
        DD_LAMBDA_HANDLER = local.quarantine_warmup_original_handler
      }) : {}
    )
  }

  logging_config {
    log_format = local.observability_enabled ? "JSON" : "Text"
    log_group  = "/braintrust/${var.deployment_name}/${local.quarantine_warmup_function_name}"
  }

  vpc_config {
    subnet_ids         = var.service_subnet_ids
    security_group_ids = [var.api_security_group_id]
  }

  ephemeral_storage {
    size = 4096
  }

  tracing_config {
    mode = "PassThrough"
  }

  tags = local.common_tags
}

# Invoke the quarantine warmup lambda function every time the api handler is deployed
resource "aws_lambda_invocation" "invoke_quarantine_warmup" {
  count      = var.use_quarantine_vpc ? 1 : 0
  depends_on = [aws_lambda_function.quarantine_warmup]

  function_name = aws_lambda_function.quarantine_warmup[0].function_name
  input         = jsonencode({})
  triggers = {
    function_version = aws_lambda_function.api_handler.version
  }
}
