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

# Execution permissions for the quarantine function role. This is a tightened,
# self-managed replacement for the AWS-managed AWSLambdaVPCAccessExecutionRole:
# the ENI management actions are authorized for the Lambda SERVICE only, by
# requiring that lambda:SourceFunctionArn is absent. That key is present only on
# calls made by running function code, so its absence identifies a call made by
# the Lambda service on the role's behalf (e.g. creating the Hyperplane ENI).
# CloudWatch Logs is granted to both the service (log delivery) and the function
# code; the function code is separately constrained to logs-only-from-VPC below.
resource "aws_iam_role_policy" "quarantine_function_execution" {
  count = var.enable_quarantine_vpc ? 1 : 0
  name  = "${var.deployment_name}-QuarantineFunctionExecution"
  role  = aws_iam_role.quarantine_function_role[0].id
  policy = jsonencode({ # nosemgrep
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowEniManagementByLambdaServiceOnly"
        Effect = "Allow"
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DescribeSubnets",
          "ec2:DeleteNetworkInterface",
          "ec2:AssignPrivateIpAddresses",
          "ec2:UnassignPrivateIpAddresses"
        ]
        Resource = "*"
        Condition = {
          # Allow only when NOT invoked by function code (i.e. the Lambda service).
          Null = {
            "lambda:SourceFunctionArn" = "true"
          }
        }
      },
      {
        Sid    = "AllowFunctionLogging"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      }
    ]
  })
}

# Lock the quarantine function role down so that it cannot make any AWS API call
# unless the call originates from inside the quarantine VPC. A Deny with
# StringNotEquals on aws:SourceVpc also fires when the key is absent (i.e. the
# request did not traverse a VPC endpoint), which is exactly what we want: calls
# that egress to public AWS endpoints are denied.
#
# The Lambda-service-managed ENI lifecycle and CloudWatch Logs calls (granted by
# aws_iam_role_policy.quarantine_function_execution above) are made by the Lambda
# service on the role's behalf and do NOT carry aws:SourceVpc, so they are
# excluded via NotAction to avoid breaking VPC networking and function logging.
resource "aws_iam_role_policy" "quarantine_function_vpc_lockdown" {
  count = var.enable_quarantine_vpc ? 1 : 0
  name  = "${var.deployment_name}-QuarantineFunctionVpcLockdown"
  role  = aws_iam_role.quarantine_function_role[0].id
  policy = jsonencode({ # nosemgrep
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyCallsNotFromQuarantineVpc"
        Effect = "Deny"
        # These are the actions the Lambda service performs on the role's behalf
        # (ENI lifecycle + log delivery). They never carry aws:SourceVpc, so they
        # must be excluded here or the function could not attach to the VPC or log.
        NotAction = [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DescribeSubnets",
          "ec2:DeleteNetworkInterface",
          "ec2:AssignPrivateIpAddresses",
          "ec2:UnassignPrivateIpAddresses",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
        Condition = {
          StringNotEquals = {
            "aws:SourceVpc" = var.quarantine_vpc_id
          }
        }
      }
    ]
  })
}

# Restrict the quarantined function's own code to CloudWatch Logs, and only when
# the call originates from inside the quarantine VPC. The lambda:SourceFunctionArn
# condition key is only present when the request is made by running function
# code, so these Denies apply solely to the function code:
#   1. it may use nothing other than the three CloudWatch Logs actions, and
#   2. any call that does not carry aws:SourceVpc for the quarantine VPC (i.e.
#      did not traverse a VPC endpoint in that VPC) is denied.
# Calls the Lambda service makes on the role's behalf (managing VPC ENIs,
# delivering logs) do not carry lambda:SourceFunctionArn, so they are unaffected.
resource "aws_iam_role_policy" "quarantine_function_code_logs_only" {
  count = var.enable_quarantine_vpc ? 1 : 0
  name  = "${var.deployment_name}-QuarantineFunctionCodeLogsOnly"
  role  = aws_iam_role.quarantine_function_role[0].id
  policy = jsonencode({ # nosemgrep
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyFunctionCodeExceptLogs"
        Effect = "Deny"
        NotAction = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
        Condition = {
          ArnLike = {
            "lambda:SourceFunctionArn" = "arn:aws:lambda:*:*:function:*"
          }
        }
      },
      {
        Sid      = "DenyFunctionCodeNotFromQuarantineVpc"
        Effect   = "Deny"
        Action   = "*"
        Resource = "*"
        Condition = {
          ArnLike = {
            "lambda:SourceFunctionArn" = "arn:aws:lambda:*:*:function:*"
          }
          StringNotEquals = {
            "aws:SourceVpc" = var.quarantine_vpc_id
          }
        }
      }
    ]
  })
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
