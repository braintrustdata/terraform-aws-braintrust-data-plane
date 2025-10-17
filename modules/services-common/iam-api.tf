# The role used by the API handler and AI proxy
resource "aws_iam_role" "api_handler_role" {
  name = "${var.deployment_name}-APIHandlerRole"
  assume_role_policy = jsonencode({ # nosemgrep
    Version = "2012-10-17"
    Statement = concat(
      # Lambda trust relationship
      [
        {
          Effect = "Allow"
          Principal = {
            Service = "lambda.amazonaws.com"
          }
          Action = "sts:AssumeRole"
        }
      ],
      # IRSA trust relationship (cluster ARN is required)
      var.enable_eks_irsa && var.eks_cluster_arn != null ? [
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
      # EKS Pod Identity trust relationship
      var.enable_eks_pod_identity ? [
        merge(
          {
            Effect = "Allow"
            Principal = {
              Service = "pods.eks.amazonaws.com"
            }
            Action = [
              "sts:AssumeRole",
              "sts:TagSession"
            ]
          },
          # Only include Condition block if at least one EKS restriction is provided
          var.eks_cluster_arn != null || var.eks_namespace != null ? {
            Condition = {
              StringEquals = merge(
                var.eks_cluster_arn != null ? {
                  "aws:RequestTag/kubernetes-cluster-arn" = [var.eks_cluster_arn]
                } : {},
                var.eks_namespace != null ? {
                  "aws:RequestTag/kubernetes-namespace" = [var.eks_namespace]
                } : {}
              )
            }
          } : {}
        )
      ] : []
    )
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
