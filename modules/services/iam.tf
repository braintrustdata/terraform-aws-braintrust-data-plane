# The role used by the API handler to invoke the used-defined quarantined function
resource "aws_iam_role" "quarantine_invoke_role" {
  name = "${var.deployment_name}-QuarantineInvokeRole"
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

  tags = {
    BraintrustDeploymentName = var.deployment_name
  }
}

resource "aws_iam_role_policy" "quarantine_invoke_policy" {
  name = "${var.deployment_name}-QuarantineInvokeRolePolicy"
  role = aws_iam_role.quarantine_invoke_role.id
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
  role_name    = aws_iam_role.quarantine_invoke_role.name
  policy_names = [aws_iam_role_policy.quarantine_invoke_policy.name]
}

# The role used by the quarantined functions
resource "aws_iam_role" "quarantine_function_role" {
  name = "${var.deployment_name}-QuarantineFunctionRole"

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

  tags = {
    BraintrustDeploymentName = var.deployment_name
  }
}

resource "aws_iam_role_policy_attachment" "quarantine_function_role" {
  role       = aws_iam_role.quarantine_function_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# The role used by the API handler and AI proxy
resource "aws_iam_role" "api_handler_role" {
  name = "${var.deployment_name}-APIHandlerRole"
  assume_role_policy = jsonencode({ # nosemgrep
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
    Version = "2012-10-17"
  })

  permissions_boundary = var.permissions_boundary_arn

  tags = {
    BraintrustDeploymentName = var.deployment_name
  }
}

resource "aws_iam_role_policy_attachment" "vpc_access" {
  role       = aws_iam_role.api_handler_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy_attachment" "api_handler_policy" {
  role       = aws_iam_role.api_handler_role.name
  policy_arn = aws_iam_policy.api_handler_policy.arn
}

resource "aws_iam_role_policy_attachment" "api_handler_additional_policy" {
  count      = length(var.service_additional_policy_arns)
  role       = aws_iam_role.api_handler_role.name
  policy_arn = var.service_additional_policy_arns[count.index]
}

resource "aws_iam_role_policy_attachment" "api_handler_quarantine" {
  count      = var.use_quarantine_vpc ? 1 : 0
  role       = aws_iam_role.api_handler_role.name
  policy_arn = aws_iam_policy.api_handler_quarantine[0].arn
}

resource "aws_iam_policy" "api_handler_quarantine" {
  count = var.use_quarantine_vpc ? 1 : 0
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
    ]
  })

  tags = {
    BraintrustDeploymentName = var.deployment_name
  }
}

resource "aws_iam_policy" "api_handler_policy" {
  name = "${var.deployment_name}-APIHandlerRolePolicy"
  policy = jsonencode({ # nosemgrep
    Statement = [
      {
        Sid      = "ElasticacheAccess"
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
        Sid    = "S3Access"
        Action = "s3:*"
        Effect = "Allow"
        Resource = concat([
          aws_s3_bucket.lambda_responses_bucket.arn,
          "${aws_s3_bucket.lambda_responses_bucket.arn}/*",
          aws_s3_bucket.code_bundle_bucket.arn,
          "${aws_s3_bucket.code_bundle_bucket.arn}/*",
          ],
          var.brainstore_s3_bucket_name != null && var.brainstore_s3_bucket_name != "" ? [
            "arn:aws:s3:::${var.brainstore_s3_bucket_name}",
            "arn:aws:s3:::${var.brainstore_s3_bucket_name}/*"
        ] : [])
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
        Resource = aws_iam_role.quarantine_function_role.arn
      },
      {
        Action   = ["ec2:DescribeSecurityGroups", "ec2:DescribeSubnets", "ec2:DescribeVpcs"]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = var.kms_key_arn
      },
      {
        Sid      = "AssumeRoleInCustomerAccountForS3Export"
        Action   = "sts:AssumeRole"
        Effect   = "Allow"
        Resource = "*"
        Condition = {
          StringLike = {
            "sts:ExternalId" = "bt:*"
          }
        }
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



