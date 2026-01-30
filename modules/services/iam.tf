locals {
  api_handler_role_name = basename(var.api_handler_role_arn)
}

# This stays because it is lambda specific
resource "aws_iam_role_policy_attachment" "vpc_access" {
  role       = local.api_handler_role_name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Additional policies for API handler that are lambda-specific
resource "aws_iam_role_policy_attachment" "api_handler_lambda_policies" {
  role       = local.api_handler_role_name
  policy_arn = aws_iam_policy.api_handler_lambda_policies.arn
}

resource "aws_iam_policy" "api_handler_lambda_policies" {
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
        Resource = aws_lambda_function.catchup_etl.arn
      },
      {
        Action   = "iam:PassRole"
        Effect   = "Allow"
        Resource = var.use_quarantine_vpc && var.quarantine_function_role_arn != null ? var.quarantine_function_role_arn : "*"
      },
      {
        Action   = ["ec2:DescribeSecurityGroups", "ec2:DescribeSubnets", "ec2:DescribeVpcs"]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
    Version = "2012-10-17"
  })

  tags = local.common_tags
}

resource "aws_iam_role" "default_role" {
  name = "${var.deployment_name}-DefaultRole"

  assume_role_policy = jsonencode({ # nosemgrep
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  permissions_boundary = var.permissions_boundary_arn

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "lambda_vpc_access" {
  role       = aws_iam_role.default_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy" "default_role_policy" {
  name = "${var.deployment_name}-DefaultRolePolicy"
  role = aws_iam_role.default_role.id

  policy = jsonencode({ # nosemgrep
    Version = "2012-10-17"
    Statement = [
      {
        Action   = ["elasticache:DescribeCacheClusters"]
        Effect   = "Allow"
        Resource = ["*"]
        Condition = {
          StringEquals = {
            "aws:ResourceTag/BraintrustDeploymentName" = var.deployment_name
          }
        }
      },
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
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
    ]
  })
}



