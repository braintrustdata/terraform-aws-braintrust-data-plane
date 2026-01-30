# Quarantine VPC IAM resources
# These resources are needed for the Quarantine VPC functionality and are deployed
# even when use_deployment_mode_external_eks = true, as they are required for
# running user-defined functions in an isolated environment.

# The role used by the API handler to invoke the user-defined quarantined functions
resource "aws_iam_role" "quarantine_invoke_role" {
  count = var.enable_quarantine_vpc ? 1 : 0
  name  = "${var.deployment_name}-QuarantineInvokeRole"
  assume_role_policy = jsonencode({ # nosemgrep
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

  permissions_boundary = var.permissions_boundary_arn

  tags = local.common_tags
}

resource "aws_iam_role_policy" "quarantine_invoke_policy" {
  count = var.enable_quarantine_vpc ? 1 : 0
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
  count     = var.enable_quarantine_vpc ? 1 : 0
  role_name = aws_iam_role.quarantine_invoke_role[0].name
  policy_names = [
    aws_iam_role_policy.quarantine_invoke_policy[0].name
  ]
}

# The role used by the quarantined functions
resource "aws_iam_role" "quarantine_function_role" {
  count = var.enable_quarantine_vpc ? 1 : 0
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
  count      = var.enable_quarantine_vpc ? 1 : 0
  role       = aws_iam_role.quarantine_function_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Policy attached to the API handler role for quarantine operations
resource "aws_iam_policy" "api_handler_quarantine" {
  count = var.enable_quarantine_vpc ? 1 : 0
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
        ]
        Resource = "arn:aws:lambda:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:function:*"
        Effect   = "Allow"
        Sid      = "QuarantinePublish"
        Condition = {
          StringEquals = {
            "lambda:VpcIds" = var.quarantine_vpc_id
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
      {
        Action   = "iam:PassRole"
        Effect   = "Allow"
        Resource = aws_iam_role.quarantine_function_role[0].arn
      },
      {
        Action   = ["ec2:DescribeSecurityGroups", "ec2:DescribeSubnets", "ec2:DescribeVpcs"]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "api_handler_quarantine" {
  count      = var.enable_quarantine_vpc ? 1 : 0
  role       = aws_iam_role.api_handler_role.name
  policy_arn = aws_iam_policy.api_handler_quarantine[0].arn
}
