resource "aws_iam_role" "filesystems" {
  name                 = "${var.deployment_name}-sandbox-filesystems"
  permissions_boundary = var.permissions_boundary_arn
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "pods.eks.amazonaws.com" }
      Action    = ["sts:AssumeRole", "sts:TagSession"]
      Condition = { StringEquals = {
        "aws:RequestTag/eks-cluster-arn"            = aws_eks_cluster.sandbox.arn
        "aws:RequestTag/kubernetes-namespace"       = local.namespace
        "aws:RequestTag/kubernetes-service-account" = "sandbox-service"
      } }
    }]
  })
  tags = local.iam_tags
}

resource "aws_iam_role_policy" "filesystems" {
  name = "sandbox-filesystem-checkpoints"
  role = aws_iam_role.filesystems.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat([
      {
        Effect   = "Allow"
        Action   = "s3:ListBucket"
        Resource = var.checkpoint_bucket_arn
        Condition = { StringLike = {
          "s3:prefix" = ["sandbox-filesystems", "sandbox-filesystems/*"]
        } }
      },
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
        Resource = "${var.checkpoint_bucket_arn}/sandbox-filesystems/*"
      },
      ], var.checkpoint_bucket_kms_key_arn == null ? [] : [{
        Effect   = "Allow"
        Action   = ["kms:Decrypt", "kms:GenerateDataKey"]
        Resource = var.checkpoint_bucket_kms_key_arn
        Condition = {
          StringEquals = { "kms:ViaService" = "s3.${data.aws_region.current.region}.amazonaws.com" }
          StringLike   = { "kms:EncryptionContext:aws:s3:arn" = [var.checkpoint_bucket_arn, "${var.checkpoint_bucket_arn}/sandbox-filesystems/*"] }
        }
    }])
  })
}

output "checkpoint_store" {
  description = "Durable filesystem checkpoint URI. Retain this bucket until its checkpoints are no longer needed."
  value       = "s3://${var.checkpoint_bucket_id}/sandbox-filesystems"
}
