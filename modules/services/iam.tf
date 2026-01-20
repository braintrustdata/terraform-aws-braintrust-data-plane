locals {
  api_handler_role_name = basename(var.api_handler_role_arn)
}

# Quarantine IAM roles are now created in the services-common module
# to support deployments with use_deployment_mode_external_eks = true
# These resources are kept for backward compatibility when roles are not passed from services-common
resource "aws_iam_role" "quarantine_invoke_role" {
  count = var.use_quarantine_vpc && var.quarantine_invoke_role_arn == null ? 1 : 0
  name  = "${var.deployment_name}-QuarantineInvokeRole"
  assume_role_policy = jsonencode({ # nosemgrep
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = var.api_handler_role_arn
        }
      }
    ]
    Version = "2012-10-17"
  })

  permissions_boundary = var.permissions_boundary_arn

  tags = local.common_tags
}

resource "aws_iam_role_policy" "quarantine_invoke_policy" {
  count = var.use_quarantine_vpc && var.quarantine_invoke_role_arn == null ? 1 : 0
  name  = "${var.deployment_name}-QuarantineInvokeRolePolicy"
  role  = aws_iam_role.quarantine_invoke_role[0].id
  policy = jsonencode({ # nosemgrep
    Statement = [
      {
        Action   = "lambda:InvokeFunction"
        Effect   = "Allow"
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:ResourceTag/BraintrustQuarantine" = "true"
          }
        }
      }
    ]
    Version = "2012-10-17"
  })
}

resource "aws_iam_role_policies_exclusive" "quarantine_invoke_role" {
  count      = var.use_quarantine_vpc && var.quarantine_invoke_role_arn == null ? 1 : 0
  role_name  = aws_iam_role.quarantine_invoke_role[0].name
  policy_names = [aws_iam_role_policy.quarantine_invoke_policy[0].name]
}

# The role used by the quarantined functions
resource "aws_iam_role" "quarantine_function_role" {
  count = var.use_quarantine_vpc && var.quarantine_function_role_arn == null ? 1 : 0
  name  = "${var.deployment_name}-QuarantineFunctionRole"

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

resource "aws_iam_role_policy_attachment" "quarantine_function_role" {
  count      = var.use_quarantine_vpc && var.quarantine_function_role_arn == null ? 1 : 0
  role       = aws_iam_role.quarantine_function_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# This stays because it is lambda specific
resource "aws_iam_role_policy_attachment" "vpc_access" {
  role       = local.api_handler_role_name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# The quarantine policy is now attached in the services-common module
# This attachment is kept for backward compatibility when the policy is created here
resource "aws_iam_role_policy_attachment" "api_handler_quarantine" {
  count      = var.use_quarantine_vpc && var.quarantine_invoke_role_arn == null ? 1 : 0
  role       = local.api_handler_role_name
  policy_arn = aws_iam_policy.api_handler_quarantine[0].arn
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
        Resource = var.use_quarantine_vpc && var.quarantine_function_role_arn != null ? var.quarantine_function_role_arn : (var.use_quarantine_vpc && length(aws_iam_role.quarantine_function_role) > 0 ? aws_iam_role.quarantine_function_role[0].arn : "*")
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

resource "aws_iam_policy" "api_handler_quarantine" {
  count = var.use_quarantine_vpc && var.quarantine_invoke_role_arn == null ? 1 : 0
  name  = "${var.deployment_name}-APIHandlerQuarantinePolicy"
  policy = jsonencode({ # nosemgrep
    Version = "2012-10-17"
    Statement = [
      {
        Action   = "lambda:InvokeFunction"
        Effect   = "Allow"
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:ResourceTag/BraintrustQuarantine" = "true"
          }
        }
      },
      {
        Action = [
          "lambda:CreateFunction",
          "lambda:PublishVersion"
        ],
        Resource = "arn:aws:lambda:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:function:*"
        Effect   = "Allow"
        Sid      = "QuarantinePublish"
        Condition = {
          StringEquals = {
            "lambda:VpcIds" = var.quarantine_vpc_id != null ? var.quarantine_vpc_id : ""
          }
        }
      },
      {
        Action   = ["lambda:TagResource"]
        Effect   = "Allow"
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:ResourceTag/BraintrustQuarantine" = "true"
          }
        }
        Sid = "TagQuarantine"
      },
      {
        Action   = ["lambda:DeleteFunction", "lambda:UpdateFunctionCode", "lambda:UpdateFunctionConfiguration", "lambda:GetFunction", "lambda:GetFunctionConfiguration"]
        Effect   = "Allow"
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:ResourceTag/BraintrustQuarantine" = "true"
          }
        }
      },
    ]
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



