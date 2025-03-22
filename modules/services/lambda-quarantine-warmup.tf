locals {
  quarantine_warmup_function_name = "${var.deployment_name}-QuarantineWarmupFunction"
}

resource "aws_lambda_function" "quarantine_warmup" {
  count = var.use_quarantine_vpc ? 1 : 0

  function_name = local.quarantine_warmup_function_name
  s3_bucket     = local.lambda_s3_bucket
  s3_key        = local.lambda_versions["QuarantineWarmupFunction"]
  role          = aws_iam_role.api_handler_role.arn
  handler       = "index.handler"
  runtime       = "nodejs20.x"
  memory_size   = 1024
  timeout       = 900
  kms_key_arn   = var.kms_key_arn

  environment {
    variables = {
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
      QUARANTINE_PUB_PRIVATE_VPC_DEFAULT_SECURITY_GROUP = var.use_quarantine_vpc ? var.quarantine_vpc_default_security_group_id : ""
      QUARANTINE_PUB_PRIVATE_VPC_ID                     = var.use_quarantine_vpc ? var.quarantine_vpc_id : ""
    }
  }

  logging_config {
    log_format = "Text"
    log_group  = "/braintrust/${var.deployment_name}/${local.quarantine_warmup_function_name}"
  }

  vpc_config {
    subnet_ids         = var.service_subnet_ids
    security_group_ids = var.service_security_group_ids
  }

  ephemeral_storage {
    size = 4096
  }

  tracing_config {
    mode = "PassThrough"
  }

  tags = {
    BraintrustDeploymentName = var.deployment_name
  }
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
