resource "aws_s3_bucket" "lambda_responses_bucket" {

  # generate a random suffix to ensure uniqueness
  bucket_prefix = "${var.deployment_name}-lambda-responses-"

  lifecycle {
    # S3 does not support renaming buckets
    ignore_changes = [bucket_prefix]
  }

  tags = local.common_tags
}

resource "aws_s3_bucket_versioning" "lambda_responses_bucket" {
  bucket = aws_s3_bucket.lambda_responses_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}


resource "aws_s3_bucket_lifecycle_configuration" "lambda_responses_bucket" {
  bucket     = aws_s3_bucket.lambda_responses_bucket.id
  depends_on = [aws_s3_bucket_versioning.lambda_responses_bucket]

  # Delete EVERYTHING from the bucket after 1 day
  rule {
    id     = "ExpireObjectsAfterOneDay"
    status = "Enabled"

    filter {
      prefix = ""
    }

    expiration {
      days = 1
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }

    noncurrent_version_expiration {
      noncurrent_days = 1
    }
  }
}

resource "aws_s3_bucket_cors_configuration" "lambda_responses_bucket" {
  bucket = aws_s3_bucket.lambda_responses_bucket.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "HEAD"]
    allowed_origins = local.all_origins
    max_age_seconds = 3600
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "lambda_responses_bucket" {
  bucket = aws_s3_bucket.lambda_responses_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.kms_key_arn != null ? "aws:kms" : "AES256"
      kms_master_key_id = var.kms_key_arn
    }
    bucket_key_enabled = var.kms_key_arn != null
  }
}

resource "aws_s3_bucket_public_access_block" "lambda_responses_bucket" {
  bucket = aws_s3_bucket.lambda_responses_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
