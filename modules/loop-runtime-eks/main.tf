data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_region" "current" {}

data "aws_eks_cluster" "cluster" {
  count = var.enable_eks_irsa && var.eks_cluster_arn != null ? 1 : 0
  name  = split("/", var.eks_cluster_arn)[1]
}

locals {
  common_tags = merge({
    BraintrustDeploymentName = var.deployment_name
  }, var.custom_tags)

  oidc_issuer_url = var.enable_eks_irsa && var.eks_cluster_arn != null ? data.aws_eks_cluster.cluster[0].identity[0].oidc[0].issuer : null
  oidc_provider   = var.enable_eks_irsa && var.eks_cluster_arn != null ? replace(local.oidc_issuer_url, "https://", "") : null
  locks_s3_path   = trimprefix(var.brainstore_locks_s3_path, "/")

  assume_role_policy = jsonencode({ # nosemgrep
    Version = "2012-10-17"
    Statement = concat(
      var.enable_eks_irsa && var.eks_cluster_arn != null ? [
        {
          Effect = "Allow"
          Principal = {
            Federated = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${local.oidc_provider}"
          }
          Action = "sts:AssumeRoleWithWebIdentity"
          Condition = {
            StringLike = {
              "${local.oidc_provider}:sub" = "system:serviceaccount:${var.eks_namespace != null ? var.eks_namespace : "*"}:*"
            }
            StringEquals = {
              "${local.oidc_provider}:aud" = "sts.amazonaws.com"
            }
          }
        }
      ] : [],
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
          var.eks_cluster_arn != null || var.eks_namespace != null ? {
            Condition = {
              StringEquals = merge(
                var.eks_cluster_arn != null ? {
                  "aws:RequestTag/eks-cluster-arn" = [var.eks_cluster_arn]
                } : {},
                var.eks_namespace != null ? {
                  "aws:RequestTag/kubernetes-namespace" = [var.eks_namespace]
                } : {}
              )
            }
          } : {}
        )
      ] : [],
    )
  })
}

# This role is intentionally separate from APIHandlerRole. The Loop Runtime
# gets only the object-store, metrics, and sandbox permissions it needs; its
# Kubernetes pod receives database/Redis URLs from the Kubernetes Secret and
# therefore must not read Secrets Manager directly.
resource "aws_iam_role" "loop_runtime" {
  name                 = "${var.deployment_name}-loop-runtime-eks"
  assume_role_policy   = local.assume_role_policy
  permissions_boundary = var.permissions_boundary_arn
  tags = merge({
    Name = "${var.deployment_name}-loop-runtime-eks"
  }, local.common_tags)

  lifecycle {
    precondition {
      condition     = !strcontains(lower(var.sandbox_policy_json), "secretsmanager")
      error_message = "sandbox_policy_json must not grant Secrets Manager access to the Loop Runtime EKS role."
    }
  }
}

resource "aws_iam_role_policy" "brainstore_s3_access" {
  name = "LoopRuntimeBrainstoreS3Access"
  role = aws_iam_role.loop_runtime.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:PutObject"]
        Resource = ["${var.brainstore_s3_bucket_arn}/brainstore/wal/object-store-objects/*"]
      },
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject"]
        Resource = ["${var.brainstore_s3_bucket_arn}/brainstore/wal/recently-updated/*"]
      },
      {
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = [var.brainstore_s3_bucket_arn]
        Condition = {
          StringLike = { "s3:prefix" = ["brainstore/wal/recently-updated/*"] }
        }
      },
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:DeleteObjectVersion"]
        Resource = ["${var.brainstore_s3_bucket_arn}/${local.locks_s3_path}/*"]
      },
      {
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = [var.brainstore_s3_bucket_arn]
        Condition = {
          StringLike = { "s3:prefix" = ["${local.locks_s3_path}/*"] }
        }
      },
    ]
  })
}

resource "aws_iam_role_policy" "code_bundle_access" {
  name = "LoopRuntimeCodeBundleAccess"
  role = aws_iam_role.loop_runtime.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject"]
        Resource = ["${var.code_bundle_s3_bucket_arn}/exo/*"]
      },
      {
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = [var.code_bundle_s3_bucket_arn]
        Condition = {
          StringLike = { "s3:prefix" = ["exo", "exo/*"] }
        }
      },
    ]
  })
}

resource "aws_iam_role_policy" "kms_access" {
  name = "LoopRuntimeKmsAccess"
  role = aws_iam_role.loop_runtime.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["kms:Decrypt", "kms:GenerateDataKey", "kms:DescribeKey"]
      Resource = var.kms_key_arn
      Condition = {
        StringEquals = {
          "kms:ViaService" = "s3.${data.aws_region.current.region}.amazonaws.com"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "cloudwatch_metrics_access" {
  name = "LoopRuntimeCloudWatchMetricsAccess"
  role = aws_iam_role.loop_runtime.id
  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Action = ["cloudwatch:PutMetricData"], Resource = "*" }]
  })
}

resource "aws_iam_role_policy" "ec2_tags_read_access" {
  name = "LoopRuntimeEC2TagsReadAccess"
  role = aws_iam_role.loop_runtime.id
  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Action = ["ec2:DescribeTags"], Resource = "*" }]
  })
}

resource "aws_iam_role_policy" "sandbox" {
  name   = "LoopRuntimeSandbox"
  role   = aws_iam_role.loop_runtime.id
  policy = var.sandbox_policy_json
}
