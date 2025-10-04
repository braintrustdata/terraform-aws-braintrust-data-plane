resource "aws_s3_bucket" "clickhouse_s3_bucket" {
  count         = var.external_clickhouse_s3_bucket_name == null ? 1 : 0
  bucket_prefix = "${var.deployment_name}-clickhouse"

  lifecycle {
    # S3 does not support renaming buckets
    ignore_changes = [bucket_prefix]
  }

  tags = local.common_tags
}

resource "aws_s3_bucket_server_side_encryption_configuration" "clickhouse_s3_bucket" {
  count  = var.external_clickhouse_s3_bucket_name == null ? 1 : 0
  bucket = aws_s3_bucket.clickhouse_s3_bucket[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.kms_key_arn != null ? "aws:kms" : "AES256"
      kms_master_key_id = var.kms_key_arn
    }
    bucket_key_enabled = var.kms_key_arn != null
  }
}

resource "aws_s3_bucket_versioning" "clickhouse_s3_bucket" {
  count  = var.external_clickhouse_s3_bucket_name == null ? 1 : 0
  bucket = aws_s3_bucket.clickhouse_s3_bucket[0].id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "clickhouse_s3_bucket" {
  count      = var.external_clickhouse_s3_bucket_name == null ? 1 : 0
  depends_on = [aws_s3_bucket_versioning.clickhouse_s3_bucket]
  bucket     = aws_s3_bucket.clickhouse_s3_bucket[0].id

  rule {
    id     = "cleanup-old-versions"
    status = "Enabled"

    filter {
      prefix = ""
    }

    # Delete old versions after 14 days (longer than other buckets since this stores data)
    noncurrent_version_expiration {
      noncurrent_days = 14
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }
}
