resource "aws_s3_bucket" "brainstore" {
  bucket_prefix = "${var.deployment_name}-brainstore-"

  lifecycle {
    ignore_changes = [
      # S3 does not support renaming buckets
      bucket_prefix
    ]
  }

  tags = local.common_tags
}

resource "aws_s3_bucket_server_side_encryption_configuration" "brainstore" {
  bucket = aws_s3_bucket.brainstore.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.kms_key_arn != null ? "aws:kms" : "AES256"
      kms_master_key_id = var.kms_key_arn
    }
    bucket_key_enabled = var.kms_key_arn != null
  }
}

resource "aws_s3_bucket_versioning" "brainstore" {
  bucket = aws_s3_bucket.brainstore.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "brainstore" {
  depends_on = [aws_s3_bucket_versioning.brainstore]
  bucket     = aws_s3_bucket.brainstore.id

  rule {
    id     = "cleanup-old-versions"
    status = "Enabled"

    filter {
      # Apply to all objects in the bucket
      prefix = ""
    }

    # Delete old versions after X days
    noncurrent_version_expiration {
      noncurrent_days = var.s3_bucket_retention_days
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }

  rule {
    id     = "delete-index-deletion-logs"
    status = "Enabled"

    filter {
      # !IMPORTANT!: do not change this path
      prefix = "brainstore/index/delete_ops/"
    }

    expiration {
      # We use the same var for the expiration interval and the delete interval
      # in cleanup-old-versions so the total time to deletion is 2 * var.s3_bucket_retention_days
      days = var.s3_bucket_retention_days
    }
  }

  rule {
    id     = "delete-wal-deletion-logs"
    status = "Enabled"

    filter {
      # !IMPORTANT!: do not change this path
      prefix = "brainstore/wal/delete_ops/"
    }

    expiration {
      # We use the same var for the expiration interval and the delete interval
      # in cleanup-old-versions so the total time to deletion is 2 * var.s3_bucket_retention_days
      days = var.s3_bucket_retention_days
    }
  }

  dynamic "rule" {
    for_each = var.intelligent_tiering_enabled ? [1] : []
    content {
      id     = "intelligent-tiering"
      status = "Enabled"

      filter {
        # Apply to all objects in the bucket
        prefix = ""
      }

      transition {
        days          = 30
        storage_class = "STANDARD_IA"
      }
    }
  }
}

resource "aws_s3_bucket_public_access_block" "brainstore" {
  bucket = aws_s3_bucket.brainstore.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
