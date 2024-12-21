resource "aws_iam_role" "quarantine_invoke_role" {
  name = "${var.deployment_name}-QuarantineInvokeRole"
  assume_role_policy = jsonencode({
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
}

resource "aws_iam_role_policy" "quarantine_invoke_policy" {
  name = "QuarantineInvokeRolePolicy"
  role = aws_iam_role.quarantine_invoke_role.id
  policy = jsonencode({
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


resource "aws_iam_role" "quarantine_function_role" {
  name = "${var.deployment_name}-QuarantineFunctionRole"

  assume_role_policy = jsonencode({
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
}

resource "aws_iam_role_policy_attachments_exclusive" "quarantine_function_role" {
  role_name = aws_iam_role.quarantine_function_role.name
  policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
  ]
}


resource "aws_iam_role" "api_handler_role" {
  name = "${var.deployment_name}-APIHandlerRole"
  assume_role_policy = jsonencode({
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
}

resource "aws_iam_role_policy" "api_handler_policy" {
  name = "${var.deployment_name}-APIHandlerRolePolicy"
  role = aws_iam_role.api_handler_role.id
  policy = jsonencode({
    Statement = [
      {
        Action   = ["elasticache:DescribeCacheClusters"]
        Effect   = "Allow"
        Resource = ["*"]
      },
      {
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Effect   = "Allow"
        Resource = "arn:*:logs:*:*:*"
      },
      {
        Action = "s3:*"
        Effect = "Allow"
        Resource = [
          "arn:aws:s3:::${aws_s3_bucket.lambda_responses_bucket.arn}",
          "arn:aws:s3:::${aws_s3_bucket.lambda_responses_bucket.arn}/*",
          "arn:aws:s3:::${aws_s3_bucket.code_bundle_bucket.arn}",
          "arn:aws:s3:::${aws_s3_bucket.code_bundle_bucket.arn}/*"
        ]
      },
      {
        Action   = ["lambda:CreateFunction", "lambda:PublishVersion"]
        Effect   = "Allow"
        Resource = "arn:aws:lambda:$${AWS::Region}:$${AWS::AccountId}:function:*"
        Sid      = "QuarantinePublish"
      },
      {
        Action   = ["lambda:CreateFunction", "lambda:PublishVersion"]
        Effect   = "Deny"
        Resource = "*"
        Condition = {
          StringNotEquals = {
            "lambda:VpcIds" = var.use_quarantine_vpc ? var.quarantine_vpc_id : ""
          }
        }
        Sid = "EnforceQuarantineVPC"
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
        Action   = ["lambda:DeleteFunction", "lambda:UpdateFunctionCode", "lambda:UpdateFunctionConfiguration", "lambda:GetFunctionConfiguration"]
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
        Resource = aws_iam_role.quarantine_function_role.arn
      },
      {
        Action   = ["ec2:DescribeSecurityGroups", "ec2:DescribeSubnets", "ec2:DescribeVpcs"]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
    Version = "2012-10-17"
  })
}

resource "aws_iam_role_policy_attachments_exclusive" "api_handler_exclusive" {
  role_name = aws_iam_role.api_handler_role.name
  policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
  ]
}

resource "aws_iam_role_policies_exclusive" "api_handler_policies_exclusive" {
  role_name    = aws_iam_role.api_handler_role.name
  policy_names = [aws_iam_role_policy.api_handler_policy.name]
}
