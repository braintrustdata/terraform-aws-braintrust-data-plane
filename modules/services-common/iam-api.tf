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

resource "aws_iam_role_policy_attachment" "api_handler_policy" {
  role       = aws_iam_role.api_handler_role.name
  policy_arn = aws_iam_policy.api_handler_policy.arn
}

resource "aws_iam_role_policy_attachment" "api_handler_additional_policy" {
  count      = length(var.service_additional_policy_arns)
  role       = aws_iam_role.api_handler_role.name
  policy_arn = var.service_additional_policy_arns[count.index]
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
        Sid    = "S3Access"
        Action = "s3:*"
        Effect = "Allow"
        Resource = concat([
          var.lambda_responses_s3_bucket_arn,
          "${var.lambda_responses_s3_bucket_arn}/*",
          var.code_bundle_s3_bucket_arn,
          "${var.code_bundle_s3_bucket_arn}/*",
          ],
          var.brainstore_s3_bucket_arn != null && var.brainstore_s3_bucket_arn != "" ? [
            var.brainstore_s3_bucket_arn,
            "${var.brainstore_s3_bucket_arn}/*"
        ] : [])
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

  tags = {
    BraintrustDeploymentName = var.deployment_name
  }
}
