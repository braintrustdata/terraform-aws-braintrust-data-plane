resource "aws_s3_bucket" "sandbox_filesystems" {
  bucket_prefix = "${var.deployment_name}-sandbox-fs-"
  force_destroy = false
  tags          = local.common_tags

  lifecycle {
    ignore_changes = [bucket_prefix]
  }
}

resource "aws_s3_bucket_abac" "sandbox_filesystems" {
  count  = var.enable_s3_bucket_abac ? 1 : 0
  bucket = aws_s3_bucket.sandbox_filesystems.id
  abac_status {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_policy" "sandbox_filesystems" {
  bucket = aws_s3_bucket.sandbox_filesystems.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "DenyInsecureTransport"
      Effect    = "Deny"
      Principal = "*"
      Action    = "s3:*"
      Resource  = [aws_s3_bucket.sandbox_filesystems.arn, "${aws_s3_bucket.sandbox_filesystems.arn}/*"]
      Condition = { Bool = { "aws:SecureTransport" = "false" } }
    }]
  })
}

resource "aws_s3_bucket_public_access_block" "sandbox_filesystems" {
  count = var.manage_s3_public_access_block ? 1 : 0

  bucket                  = aws_s3_bucket.sandbox_filesystems.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "sandbox_filesystems" {
  bucket = aws_s3_bucket.sandbox_filesystems.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "sandbox_filesystems" {
  bucket = aws_s3_bucket.sandbox_filesystems.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.kms_key_arn != null ? "aws:kms" : "AES256"
      kms_master_key_id = var.kms_key_arn
    }
    bucket_key_enabled = var.kms_key_arn != null
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "sandbox_filesystems" {
  bucket = aws_s3_bucket.sandbox_filesystems.id
  rule {
    id     = "ExpireSandboxCheckpoints"
    status = "Enabled"
    filter {
      prefix = "sandbox-filesystems/sandbox-checkpoints-v1/"
    }
    expiration {
      days = var.sandbox_checkpoint_retention_days
    }
  }
  rule {
    id     = "AbortIncompleteMultipartUploads"
    status = "Enabled"
    filter {}
    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }
}

