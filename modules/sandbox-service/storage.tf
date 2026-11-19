resource "aws_s3_bucket" "filesystems" {
  bucket_prefix = "${var.deployment_name}-sandbox-fs-"
  force_destroy = false
  tags          = local.common_tags
}

resource "aws_s3_bucket_public_access_block" "filesystems" {
  bucket                  = aws_s3_bucket.filesystems.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "filesystems" {
  bucket = aws_s3_bucket.filesystems.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "filesystems" {
  bucket = aws_s3_bucket.filesystems.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "filesystems" {
  bucket = aws_s3_bucket.filesystems.id
  rule {
    id     = "AbortIncompleteMultipartUploads"
    status = "Enabled"
    filter {}
    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }
}

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
    Statement = [
      {
        Effect   = "Allow"
        Action   = "s3:ListBucket"
        Resource = aws_s3_bucket.filesystems.arn
        Condition = { StringLike = {
          "s3:prefix" = ["sandbox-filesystems", "sandbox-filesystems/*"]
        } }
      },
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
        Resource = "${aws_s3_bucket.filesystems.arn}/sandbox-filesystems/*"
      },
    ]
  })
}

output "checkpoint_store" {
  description = "Durable filesystem checkpoint URI. Retain this bucket until its checkpoints are no longer needed."
  value       = "s3://${aws_s3_bucket.filesystems.id}/sandbox-filesystems"
}
