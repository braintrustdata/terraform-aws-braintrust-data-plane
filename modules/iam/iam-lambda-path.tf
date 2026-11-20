# IAM that only the Lambda API path uses: the APIHandler-Lambdas policy and the
# AIProxy invoke role. enable_ecs_api removes the AIProxy role. This file is
# separate so it can go when the Lambda path does.

locals {
  # Built from the function names in modules/services, so these policies don't
  # wait for the functions, which wait for these roles.
  lambda_function_arn_prefix = "arn:${data.aws_partition.current.partition}:lambda:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:function:${var.deployment_name}"
}

resource "aws_iam_role_policy_attachment" "api_handler_vpc_access" {
  count = var.create_iam && local.create_lambda_services ? 1 : 0

  role       = aws_iam_role.api_handler[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy_attachment" "api_handler_lambda_policies" {
  count = var.create_iam && local.create_lambda_services ? 1 : 0

  role       = aws_iam_role.api_handler[0].name
  policy_arn = aws_iam_policy.api_handler_lambda_policies[0].arn
}

resource "aws_iam_policy" "api_handler_lambda_policies" {
  count = var.create_iam && local.create_lambda_services ? 1 : 0

  name = "${var.deployment_name}-APIHandler-Lambdas"
  policy = jsonencode({ # nosemgrep
    Statement = [
      {
        Sid    = "CloudWatchLogs"
        Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Effect = "Allow"
        Resource = [
          # Old naming scheme
          "arn:aws:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/*",
          "arn:aws:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/*:*",
          # New naming scheme
          "arn:aws:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:/braintrust/${var.deployment_name}/*:*",
          "arn:aws:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:/braintrust/${var.deployment_name}/*",
        ]
      },
      {
        Sid      = "CatchupETLInvoke"
        Action   = ["lambda:InvokeFunction"]
        Effect   = "Allow"
        Resource = "${local.lambda_function_arn_prefix}-CatchupETL"
      }
    ]
    Version = "2012-10-17"
  })

  tags = local.iam_tags
}

resource "aws_iam_role" "ai_proxy_invoke" {
  count = var.create_iam && local.create_lambda_services && !local.enable_ecs_api ? 1 : 0

  name = local.role_names.ai_proxy_invoke
  assume_role_policy = jsonencode({ # nosemgrep
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.api_handler[0].arn
        }
      }
    ]
    Version = "2012-10-17"
  })

  permissions_boundary = var.permissions_boundary_arn

  tags = local.iam_tags
}

resource "aws_iam_role_policy" "ai_proxy_invoke" {
  count = var.create_iam && local.create_lambda_services && !local.enable_ecs_api ? 1 : 0

  name = "AIProxyInvokeRolePolicy"
  role = aws_iam_role.ai_proxy_invoke[0].id
  policy = jsonencode({ # nosemgrep
    Statement = [
      {
        Action   = "lambda:InvokeFunction"
        Effect   = "Allow"
        Resource = ["${local.lambda_function_arn_prefix}-AIProxy"]
      }
    ]
    Version = "2012-10-17"
  })
}

resource "aws_iam_role_policies_exclusive" "ai_proxy_invoke" {
  count = var.create_iam && local.create_lambda_services && !local.enable_ecs_api ? 1 : 0

  role_name    = aws_iam_role.ai_proxy_invoke[0].name
  policy_names = [aws_iam_role_policy.ai_proxy_invoke[0].name]
}
