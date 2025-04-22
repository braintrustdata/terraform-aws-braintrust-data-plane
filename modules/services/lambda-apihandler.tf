locals {
  api_handler_function_name = "${var.deployment_name}-APIHandler"
}
resource "aws_lambda_function" "api_handler" {
  # Require the DB migrations to be run before the API handler is deployed
  depends_on = [aws_lambda_invocation.invoke_database_migration]

  function_name = local.api_handler_function_name
  s3_bucket     = local.lambda_s3_bucket
  s3_key        = local.lambda_versions["APIHandler"]
  role          = aws_iam_role.api_handler_role.arn
  handler       = "index.handler"
  runtime       = "nodejs20.x"
  memory_size   = 10240 # Max that lambda supports
  timeout       = 600
  publish       = true
  architectures = ["arm64"]
  kms_key_arn   = var.kms_key_arn

  logging_config {
    log_format = "Text"
    log_group  = "/braintrust/${var.deployment_name}/${local.api_handler_function_name}"
  }

  layers = [
    # See https://github.com/tobilg/duckdb-nodejs-layer
    "arn:aws:lambda:${data.aws_region.current.name}:041475135427:layer:duckdb-nodejs-arm64:12"
  ]

  ephemeral_storage {
    size = 4096
  }

  environment {
    variables = merge({
      ORG_NAME                   = var.braintrust_org_name
      BRAINTRUST_DEPLOYMENT_NAME = var.deployment_name

      PG_URL              = local.postgres_url
      REDIS_HOST          = var.redis_host
      REDIS_PORT          = var.redis_port
      CATCHUP_ETL_ARN     = aws_lambda_function.catchup_etl.arn
      WHITELISTED_ORIGINS = join(",", var.whitelisted_origins)
      RESPONSE_BUCKET     = aws_s3_bucket.lambda_responses_bucket.id
      CODE_BUNDLE_BUCKET  = aws_s3_bucket.code_bundle_bucket.id

      OUTBOUND_RATE_LIMIT_WINDOW_MINUTES = var.outbound_rate_limit_window_minutes
      OUTBOUND_RATE_LIMIT_MAX_REQUESTS   = var.outbound_rate_limit_max_requests

      AI_PROXY_FN_ARN      = aws_lambda_function.ai_proxy.arn
      AI_PROXY_FN_URL      = aws_lambda_function_url.ai_proxy.function_url
      AI_PROXY_INVOKE_ROLE = aws_iam_role.ai_proxy_invoke_role.arn

      QUARANTINE_INVOKE_ROLE                            = var.use_quarantine_vpc ? aws_iam_role.quarantine_invoke_role.arn : ""
      QUARANTINE_FUNCTION_ROLE                          = var.use_quarantine_vpc ? aws_iam_role.quarantine_function_role.arn : ""
      QUARANTINE_PRIVATE_SUBNET_1_ID                    = var.use_quarantine_vpc ? var.quarantine_vpc_private_subnets[0] : ""
      QUARANTINE_PRIVATE_SUBNET_2_ID                    = var.use_quarantine_vpc ? var.quarantine_vpc_private_subnets[1] : ""
      QUARANTINE_PRIVATE_SUBNET_3_ID                    = var.use_quarantine_vpc ? var.quarantine_vpc_private_subnets[2] : ""
      QUARANTINE_PUB_PRIVATE_VPC_DEFAULT_SECURITY_GROUP = var.use_quarantine_vpc ? var.quarantine_vpc_default_security_group_id : ""
      QUARANTINE_PUB_PRIVATE_VPC_ID                     = var.use_quarantine_vpc ? var.quarantine_vpc_id : ""

      FUNCTION_SECRET_KEY = aws_secretsmanager_secret_version.function_tools_secret.secret_string

      BRAINSTORE_ENABLED                         = var.brainstore_enabled
      BRAINSTORE_URL                             = local.brainstore_url
      BRAINSTORE_REALTIME_WAL_BUCKET             = local.brainstore_s3_bucket
      BRAINSTORE_ENABLE_HISTORICAL_FULL_BACKFILL = var.brainstore_enable_historical_full_backfill
      BRAINSTORE_BACKFILL_NEW_OBJECTS            = var.brainstore_backfill_new_objects
      BRAINSTORE_BACKFILL_DISABLE_HISTORICAL     = var.brainstore_backfill_disable_historical
      BRAINSTORE_BACKFILL_DISABLE_NONHISTORICAL  = var.brainstore_backfill_disable_nonhistorical

      CLICKHOUSE_PG_URL      = local.clickhouse_pg_url
      CLICKHOUSE_CONNECT_URL = local.clickhouse_connect_url
    }, var.extra_env_vars.APIHandler)
  }

  vpc_config {
    subnet_ids         = var.service_subnet_ids
    security_group_ids = var.service_security_group_ids
  }

  tracing_config {
    mode = "PassThrough"
  }

  tags = local.common_tags
}

resource "aws_lambda_provisioned_concurrency_config" "api_handler_live" {
  count                             = var.api_handler_provisioned_concurrency > 0 ? 1 : 0
  function_name                     = aws_lambda_function.api_handler.function_name
  provisioned_concurrent_executions = var.api_handler_provisioned_concurrency
  qualifier                         = aws_lambda_alias.api_handler_live.name
}

resource "aws_lambda_alias" "api_handler_live" {
  name             = "live"
  function_name    = aws_lambda_function.api_handler.function_name
  function_version = aws_lambda_function.api_handler.version
}

resource "aws_iam_role" "ai_proxy_invoke_role" {
  name = "${var.deployment_name}-AIProxyInvokeRole"
  assume_role_policy = jsonencode({
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.api_handler_role.arn
        }
      }
    ]
    Version = "2012-10-17"
  })
  tags = local.common_tags
}

resource "aws_iam_role_policy" "ai_proxy_invoke_policy" {
  name = "AIProxyInvokeRolePolicy"
  role = aws_iam_role.ai_proxy_invoke_role.id
  policy = jsonencode({
    Statement = [
      {
        Action   = "lambda:InvokeFunction"
        Effect   = "Allow"
        Resource = [aws_lambda_function.ai_proxy.arn]
      }
    ]
    Version = "2012-10-17"
  })
}

resource "aws_iam_role_policies_exclusive" "ai_proxy_invoke_role" {
  role_name    = aws_iam_role.ai_proxy_invoke_role.name
  policy_names = [aws_iam_role_policy.ai_proxy_invoke_policy.name]
}
