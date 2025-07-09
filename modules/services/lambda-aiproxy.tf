locals {
  ai_proxy_function_name = "${var.deployment_name}-AIProxy"
}
resource "aws_lambda_function" "ai_proxy" {
  function_name                  = local.ai_proxy_function_name
  s3_bucket                      = local.lambda_s3_bucket
  s3_key                         = local.lambda_versions["AIProxy"]
  role                           = aws_iam_role.api_handler_role.arn
  handler                        = "index.handler"
  runtime                        = "nodejs22.x"
  architectures                  = ["arm64"]
  memory_size                    = 1024
  reserved_concurrent_executions = var.ai_proxy_reserved_concurrent_executions
  timeout                        = 900
  publish                        = true
  kms_key_arn                    = var.kms_key_arn

  logging_config {
    log_format = "Text"
    log_group  = "/braintrust/${var.deployment_name}/${local.ai_proxy_function_name}"
  }

  ephemeral_storage {
    size = 1024
  }

  environment {
    variables = merge({
      ORG_NAME                                          = var.braintrust_org_name
      PG_URL                                            = local.postgres_url
      REDIS_HOST                                        = var.redis_host
      REDIS_PORT                                        = var.redis_port
      CODE_BUNDLE_BUCKET                                = aws_s3_bucket.code_bundle_bucket.id
      FUNCTION_SECRET_KEY                               = aws_secretsmanager_secret_version.function_tools_secret.secret_string
      QUARANTINE_FUNCTION_ROLE                          = var.use_quarantine_vpc ? aws_iam_role.quarantine_function_role.arn : ""
      QUARANTINE_INVOKE_ROLE                            = var.use_quarantine_vpc ? aws_iam_role.quarantine_invoke_role.arn : ""
      QUARANTINE_PRIVATE_SUBNET_1_ID                    = var.use_quarantine_vpc ? var.quarantine_vpc_private_subnets[0] : ""
      QUARANTINE_PRIVATE_SUBNET_2_ID                    = var.use_quarantine_vpc ? var.quarantine_vpc_private_subnets[1] : ""
      QUARANTINE_PRIVATE_SUBNET_3_ID                    = var.use_quarantine_vpc ? var.quarantine_vpc_private_subnets[2] : ""
      QUARANTINE_PUB_PRIVATE_VPC_DEFAULT_SECURITY_GROUP = var.use_quarantine_vpc ? aws_security_group.quarantine_lambda.id : ""
      QUARANTINE_PUB_PRIVATE_VPC_ID                     = var.use_quarantine_vpc ? var.quarantine_vpc_id : ""
    }, var.extra_env_vars.AIProxy)
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
      "x-bt-internal-trace-id"
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
