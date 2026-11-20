# Quarantine VPC IAM resources
# These resources are needed for the Quarantine VPC functionality and are deployed
# even when use_deployment_mode_external_eks = true, as they are required for
# running user-defined functions in an isolated environment.

# The role used by the API handler to invoke the user-defined quarantined functions
resource "aws_iam_role" "quarantine_invoke" {
  count = var.create_iam && var.enable_quarantine_vpc ? 1 : 0

  name = local.role_names.quarantine_invoke
  path = local.role_paths.quarantine_invoke
  assume_role_policy = jsonencode({ # nosemgrep
    Statement = [
      {
        Sid    = "AllowAPIHandlerAssumeRole"
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

resource "aws_iam_role_policy" "quarantine_invoke" {
  count = var.create_iam && var.enable_quarantine_vpc ? 1 : 0

  name = "${var.deployment_name}-QuarantineInvokeRolePolicy"
  role = aws_iam_role.quarantine_invoke[0].id
  policy = jsonencode({ # nosemgrep
    Statement = [
      {
        Sid      = "AllowInvokeQuarantineFunctions"
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

resource "aws_iam_role_policies_exclusive" "quarantine_invoke" {
  count = var.create_iam && var.enable_quarantine_vpc ? 1 : 0

  role_name = aws_iam_role.quarantine_invoke[0].name
  policy_names = [
    aws_iam_role_policy.quarantine_invoke[0].name
  ]
}

# The role used by the quarantined functions
resource "aws_iam_role" "quarantine_function" {
  count = var.create_iam && var.enable_quarantine_vpc ? 1 : 0

  name = local.role_names.quarantine_function
  path = local.role_paths.quarantine_function

  assume_role_policy = jsonencode({ # nosemgrep
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowLambdaAssumeRole"
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  permissions_boundary = var.permissions_boundary_arn

  tags = local.iam_tags
}

resource "aws_iam_role_policy_attachment" "quarantine_function_vpc_access" {
  count = var.create_iam && var.enable_quarantine_vpc ? 1 : 0

  role       = aws_iam_role.quarantine_function[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy" "quarantine_function_deny_ec2" {
  count = var.create_iam && var.enable_quarantine_vpc ? 1 : 0

  name = "DenyEC2FromFunctionCode"
  role = aws_iam_role.quarantine_function[0].id
  policy = jsonencode({ # nosemgrep
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyNetworkInterfaceActionsFromFunctionCode"
        Effect = "Deny"
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DescribeSubnets",
          "ec2:DeleteNetworkInterface",
          "ec2:DetachNetworkInterface",
          "ec2:AssignPrivateIpAddresses",
          "ec2:UnassignPrivateIpAddresses"
        ]
        Resource = "*"
        Condition = {
          ArnLike = {
            "lambda:SourceFunctionArn" = "arn:aws:lambda:*:*:function:*"
          }
        }
      }
    ]
  })
}

# Policy attached to the API handler role for quarantine operations
resource "aws_iam_policy" "api_handler_quarantine" {
  count = var.create_iam && var.enable_quarantine_vpc ? 1 : 0

  name = "${var.deployment_name}-APIHandlerQuarantinePolicy"
  policy = jsonencode({ # nosemgrep
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "AllowInvokeQuarantineFunctions"
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
        Sid = "AllowPublishQuarantineFunctions"
        Action = [
          "lambda:CreateFunction",
          "lambda:PublishVersion"
        ]
        Resource = "arn:aws:lambda:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:function:*"
        Effect   = "Allow"
        Condition = {
          StringEquals = {
            "lambda:VpcIds" = local.quarantine_vpc_id
          }
        }
      },
      {
        Sid      = "AllowTagQuarantineFunctions"
        Action   = ["lambda:TagResource"]
        Effect   = "Allow"
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:ResourceTag/BraintrustQuarantine" = "true"
          }
        }
      },
      {
        Sid      = "AllowManageQuarantineFunctions"
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
        Sid      = "AllowPassQuarantineFunctionRole"
        Action   = "iam:PassRole"
        Effect   = "Allow"
        Resource = aws_iam_role.quarantine_function[0].arn
      },
      {
        Sid      = "AllowDescribeQuarantineNetwork"
        Action   = ["ec2:DescribeSecurityGroups", "ec2:DescribeSubnets", "ec2:DescribeVpcs"]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })

  tags = local.iam_tags

  lifecycle {
    precondition {
      condition     = local.quarantine_vpc_id != null
      error_message = "The quarantine policy needs the quarantine VPC ID. Pass it in created_resources or existing_quarantine_vpc_id."
    }
  }
}

resource "aws_iam_role_policy_attachment" "api_handler_quarantine" {
  count = var.create_iam && var.enable_quarantine_vpc ? 1 : 0

  role       = aws_iam_role.api_handler[0].name
  policy_arn = aws_iam_policy.api_handler_quarantine[0].arn
}
