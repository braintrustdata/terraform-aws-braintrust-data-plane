resource "aws_s3_bucket" "code_bundle_bucket" {
  # S3 bucket names are globally unique so we have to use a prefix and let terraform
  # generate a random suffix to ensure uniqueness
  bucket_prefix = "${var.deployment_name}-code-bundles-"

  lifecycle {
    # S3 does not support renaming buckets
    ignore_changes = [bucket_prefix]
  }

  tags = {
    BraintrustDeploymentName = var.deployment_name
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "code_bundle_bucket" {
  bucket = aws_s3_bucket.code_bundle_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.kms_key_arn != null ? "aws:kms" : "AES256"
      kms_master_key_id = var.kms_key_arn
    }
    bucket_key_enabled = var.kms_key_arn != null
  }
}

resource "aws_s3_bucket" "lambda_responses_bucket" {
  # S3 bucket names are globally unique so we have to use a prefix and let terraform
  # generate a random suffix to ensure uniqueness
  bucket_prefix = "${var.deployment_name}-lambda-responses-"

  lifecycle {
    # S3 does not support renaming buckets
    ignore_changes = [bucket_prefix]
  }

  tags = {
    BraintrustDeploymentName = var.deployment_name
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
