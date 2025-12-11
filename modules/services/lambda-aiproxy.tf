locals {
  ai_proxy_base_function_name = "AIProxy"
  ai_proxy_function_name      = "${var.deployment_name}-${local.ai_proxy_base_function_name}"
  ai_proxy_original_handler   = "index.handler"
}
resource "aws_lambda_function" "ai_proxy" {
  depends_on = [aws_lambda_invocation.invoke_database_migration]

  function_name                  = local.ai_proxy_function_name
  s3_bucket                      = local.lambda_s3_bucket
  s3_key                         = local.lambda_versions[local.ai_proxy_base_function_name]
  role                           = var.api_handler_role_arn
  handler                        = local.observability_enabled ? local.nodejs_datadog_handler : local.ai_proxy_original_handler
  runtime                        = "nodejs22.x"
  architectures                  = ["arm64"]
  memory_size                    = 10240 # Max that lambda supports
  reserved_concurrent_executions = var.ai_proxy_reserved_concurrent_executions
  timeout                        = 900
  publish                        = true
  kms_key_arn                    = var.kms_key_arn
  # See https://github.com/tobilg/duckdb-nodejs-layer
  layers = concat(
    [local.duckdb_nodejs_arm64_layer_arn],
    local.observability_enabled ? [local.datadog_node_layer_arn, local.datadog_extension_arm_layer_arn] : []
  )

  logging_config {
    log_format = local.observability_enabled ? "JSON" : "Text"
    log_group  = "/braintrust/${var.deployment_name}/${local.ai_proxy_function_name}"
  }

  ephemeral_storage {
    size = 1024
  }

  environment {
    variables = merge(
      local.api_common_env_vars,
      var.extra_env_vars.AIProxy,
      local.observability_enabled ? merge(local.datadog_env_vars, {
        DD_SERVICE        = local.ai_proxy_base_function_name
        DD_LAMBDA_HANDLER = local.ai_proxy_original_handler
      }) : {}
    )
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

resource "aws_lambda_function_url" "ai_proxy" {
  function_name      = aws_lambda_function.ai_proxy.function_name
  authorization_type = "NONE"
  invoke_mode        = "RESPONSE_STREAM"
  cors {
    allow_credentials = true
    allow_origins     = ["*"]
    allow_methods     = ["POST", "GET"]
    allow_headers = [
      "authorization",
      "content-type",
      "x-bt-org-name",
      "x-bt-auth-token",
      "x-bt-stream-fmt",
      "x-bt-use-cache",
      "x-bt-app-origin",
      "x-bt-parent",
      "x-stainless-os",
      "x-stainless-lang",
      "x-stainless-package-version",
      "x-stainless-runtime",
      "x-stainless-runtime-version",
      "x-stainless-arch"
    ]
    expose_headers = [
      "content-type",
      "keep-alive",
      "access-control-allow-credentials",
      "access-control-allow-origin",
      "access-control-allow-methods",
      "x-bt-internal-trace-id",
      "x-bt-span-id"
    ]
    max_age = 86400
  }
}
resource "aws_lambda_alias" "ai_proxy_live" {
  name             = "live"
  function_name    = aws_lambda_function.ai_proxy.function_name
  function_version = aws_lambda_function.ai_proxy.version
}

resource "aws_lambda_permission" "ai_proxy" {
  statement_id = "AllowFunctionURLInvoke"
  action       = "lambda:InvokeFunctionUrl"

  function_name          = aws_lambda_function.ai_proxy.function_name
  qualifier              = aws_lambda_alias.ai_proxy_live.name
  principal              = "*"
  function_url_auth_type = "NONE"
}
