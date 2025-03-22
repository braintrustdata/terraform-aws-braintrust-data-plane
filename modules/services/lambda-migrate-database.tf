locals {
  migrate_database_function_name = "${var.deployment_name}-MigrateDatabaseFunction"
}

resource "aws_lambda_function" "migrate_database" {
  function_name = local.migrate_database_function_name
  s3_bucket     = local.lambda_s3_bucket
  s3_key        = local.lambda_versions["MigrateDatabaseFunction"]
  role          = aws_iam_role.default_role.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.9"
  memory_size   = 1024
  timeout       = 900
  publish       = true
  kms_key_arn   = var.kms_key_arn

  logging_config {
    log_format = "Text"
    log_group  = "/braintrust/${var.deployment_name}/${local.migrate_database_function_name}"
  }
  environment {
    variables = {
      BRAINTRUST_RUN_DRAFT_MIGRATIONS = var.run_draft_migrations
      PG_URL                          = local.postgres_url
      CLICKHOUSE_CONNECT_URL          = local.clickhouse_connect_url
    }
  }

  vpc_config {
    subnet_ids         = var.service_subnet_ids
    security_group_ids = var.service_security_group_ids
  }

  tags = {
    BraintrustDeploymentName = var.deployment_name
  }
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
