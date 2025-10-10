resource "aws_iam_role" "brainstore_role" {
  # This is improperly named with "ec2" but changing it would cause a downtime for current customers
  name = "${var.deployment_name}-brainstore-ec2-role"

  assume_role_policy = jsonencode({ # nosemgrep
    Version = "2012-10-17"
    Statement = concat(
      # EC2 trust relationship
      [
        {
          Effect = "Allow"
          Principal = {
            Service = "ec2.amazonaws.com"
          }
          Action = "sts:AssumeRole"
        }
      ],
      # IRSA trust relationship (if cluster ARN is provided)
      var.eks_cluster_arn != null ? [
        {
          Effect = "Allow"
          Principal = {
            Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${replace(local.eks_oidc_issuer_url, "https://", "")}"
          }
          Action = "sts:AssumeRoleWithWebIdentity"
          Condition = {
            StringEquals = {
              "${replace(local.eks_oidc_issuer_url, "https://", "")}:sub" = "system:serviceaccount:${var.eks_namespace != null ? var.eks_namespace : "*"}:*"
              "${replace(local.eks_oidc_issuer_url, "https://", "")}:aud" = "sts.amazonaws.com"
            }
          }
        }
      ] : [],
      # EKS Pod Identity trust relationship (always enabled)
      [
        {
          Effect = "Allow"
          Principal = {
            Service = "pods.eks.amazonaws.com"
          }
          Action = [
            "sts:AssumeRole",
            "sts:TagSession"
          ]
          Condition = merge(
            var.eks_cluster_arn != null ? {
              "aws:RequestTag/kubernetes-cluster-arn" = var.eks_cluster_arn
            } : {},
            var.eks_namespace != null ? {
              "aws:RequestTag/kubernetes-namespace" = var.eks_namespace
            } : {}
          )
        }
      ]
    )
  })

  permissions_boundary = var.permissions_boundary_arn

  tags = merge({
    Name = "${var.deployment_name}-brainstore-ec2-role"
  }, local.common_tags)
}

resource "aws_iam_role_policy" "brainstore_s3_access" {
  name = "brainstore-s3-bucket"
  role = aws_iam_role.brainstore_role.id

  policy = jsonencode({ # nosemgrep
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:AbortMultipartUpload",
          "s3:Get*",
          "s3:PutObject*",
          "s3:List*",
          "s3:DeleteObject*"
        ]
        Resource = [
          var.brainstore_s3_bucket_arn,
          "${var.brainstore_s3_bucket_arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy" "brainstore_secrets_access" {
  name = "secrets-access"
  role = aws_iam_role.brainstore_role.id

  policy = jsonencode({ # nosemgrep
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "secretsmanager:GetSecretValue"
        Resource = var.database_secret_arn
      }
    ]
  })
}

resource "aws_iam_role_policy" "brainstore_cloudwatch_logs_access" {
  name = "cloudwatch-logs-access"
  role = aws_iam_role.brainstore_role.id

  policy = jsonencode({ # nosemgrep
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = [
          "arn:aws:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:/braintrust/${var.deployment_name}/brainstore:*",
          "arn:aws:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:/braintrust/${var.deployment_name}/brainstore/*:*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy" "brainstore_kms_policy" {
  name = "${var.deployment_name}-brainstore-kms-policy"
  role = aws_iam_role.brainstore_role.id

  policy = jsonencode({ # nosemgrep
    Version = "2012-10-17"
    Statement = [
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
      }
    ]
  })
}


