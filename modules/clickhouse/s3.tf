resource "aws_s3_bucket" "clickhouse_s3_bucket" {
  count         = var.external_clickhouse_s3_bucket_name == null ? 1 : 0
  bucket_prefix = "${var.deployment_name}-clickhouse"

  lifecycle {
    # S3 does not support renaming buckets
    ignore_changes = [bucket_prefix]
  }

  tags = {
    BraintrustDeploymentName = var.deployment_name
  }
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
