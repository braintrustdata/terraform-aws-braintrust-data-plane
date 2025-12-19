locals {
  migrate_database_base_function_name = "MigrateDatabaseFunction"
  migrate_database_function_name      = "${var.deployment_name}-${local.migrate_database_base_function_name}"
  migrate_database_original_handler   = "lambda_function.lambda_handler"
}

resource "aws_cloudwatch_log_group" "migrate_database" {
  name              = "/braintrust/${var.deployment_name}/${local.migrate_database_function_name}"
  retention_in_days = 90

  tags = local.common_tags
}

resource "aws_lambda_function" "migrate_database" {
  function_name = local.migrate_database_function_name
  s3_bucket     = local.lambda_s3_bucket
  s3_key        = local.lambda_versions[local.migrate_database_base_function_name]
  role          = aws_iam_role.default_role.arn
  handler       = local.observability_enabled ? local.python_datadog_handler : local.migrate_database_original_handler
  runtime       = "python3.13"
  memory_size   = 1024
  timeout       = 900
  publish       = true
  kms_key_arn   = var.kms_key_arn

  layers = local.observability_enabled ? [local.datadog_python_layer_arn, local.datadog_extension_layer_arn] : []

  logging_config {
    log_format = local.observability_enabled ? "JSON" : "Text"
    log_group  = "/braintrust/${var.deployment_name}/${local.migrate_database_function_name}"
  }
  environment {
    variables = merge({
      BRAINTRUST_RUN_DRAFT_MIGRATIONS = var.run_draft_migrations
      PG_URL                          = local.postgres_url
      CLICKHOUSE_CONNECT_URL          = local.clickhouse_connect_url
      INSERT_LOGS2                    = "true"
      },
      var.extra_env_vars.MigrateDatabaseFunction,
      local.observability_enabled ? merge(local.datadog_env_vars, {
        DD_SERVICE        = local.migrate_database_base_function_name
        DD_LAMBDA_HANDLER = local.migrate_database_original_handler
      }) : {}
    )
  }

  vpc_config {
    subnet_ids         = var.service_subnet_ids
    security_group_ids = [var.api_security_group_id]
  }

  tags = local.common_tags
}

# This is mainly for convenience to be able to manually invoke the latest
resource "aws_lambda_alias" "migrate_database_live" {
  name             = "live"
  function_name    = aws_lambda_function.migrate_database.function_name
  function_version = aws_lambda_function.migrate_database.version
}

# Invoke the database migration lambda function every time the version changes
resource "aws_lambda_invocation" "invoke_database_migration" {
  function_name = aws_lambda_function.migrate_database.function_name
  input         = jsonencode({})
  triggers = {
    function_version = aws_lambda_function.migrate_database.version
  }
}
