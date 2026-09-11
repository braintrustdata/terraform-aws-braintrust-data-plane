# Plan-mode tests for the optional caller-provided attachment S3 bucket
# (existing_attachment_s3_bucket_arn / existing_attachment_s3_bucket_kms_key_arn).
#
# The module must never create, own, or modify the bucket. These tests assert
# the derived outputs for the configured, encrypted, and unconfigured shapes and
# confirm that enabling the feature adds no bucket resources (storage module is
# unchanged, so no attachment bucket is created or replaced).

mock_provider "aws" {
  source = "./tests/mocks/aws"
}

mock_provider "random" {}

mock_provider "http" {
  source = "./tests/mocks/http"
}

variables {
  braintrust_org_name    = "test-org"
  primary_org_name       = "test-org"
  deployment_name        = "bt-test"
  brainstore_license_key = "test-license"
  enable_quarantine_vpc  = true
}

# Feature disabled (default): outputs are null and no attachment bucket exists.
run "attachment_disabled_plans" {
  command = plan

  assert {
    condition     = output.attachment_s3_bucket_name == null
    error_message = "attachment_s3_bucket_name should be null when the feature is disabled"
  }

  assert {
    condition     = output.attachment_s3_bucket_arn == null
    error_message = "attachment_s3_bucket_arn should be null when the feature is disabled"
  }
}

# Feature configured with an unencrypted (SSE-S3) external bucket.
run "attachment_configured_plans" {
  command = plan

  variables {
    existing_attachment_s3_bucket_arn = "arn:aws:s3:::example-attachment-bucket"
  }

  assert {
    condition     = output.attachment_s3_bucket_arn == "arn:aws:s3:::example-attachment-bucket"
    error_message = "attachment_s3_bucket_arn should echo the caller-provided ARN, not a module-created bucket"
  }

  assert {
    condition     = output.attachment_s3_bucket_name == "example-attachment-bucket"
    error_message = "attachment_s3_bucket_name should be derived from the ARN"
  }
}

# Feature configured with an encrypted (SSE-KMS) external bucket.
run "attachment_encrypted_plans" {
  command = plan

  variables {
    existing_attachment_s3_bucket_arn         = "arn:aws:s3:::example-attachment-bucket"
    existing_attachment_s3_bucket_kms_key_arn = "arn:aws:kms:us-east-1:123456789012:key/00000000-0000-0000-0000-000000000000"
  }

  assert {
    condition     = output.attachment_s3_bucket_arn == "arn:aws:s3:::example-attachment-bucket"
    error_message = "attachment_s3_bucket_arn should echo the caller-provided ARN for the encrypted bucket"
  }

  assert {
    condition     = output.attachment_s3_bucket_name == "example-attachment-bucket"
    error_message = "attachment_s3_bucket_name should be derived from the ARN for the encrypted bucket"
  }
}

# The KMS key ARN requires the bucket ARN.
run "rejects_kms_without_bucket" {
  command = plan

  variables {
    existing_attachment_s3_bucket_kms_key_arn = "arn:aws:kms:us-east-1:123456789012:key/00000000-0000-0000-0000-000000000000"
  }

  expect_failures = [
    var.existing_attachment_s3_bucket_kms_key_arn,
  ]
}

# A non-S3 ARN is rejected.
run "rejects_non_s3_bucket_arn" {
  command = plan

  variables {
    existing_attachment_s3_bucket_arn = "arn:aws:kms:us-east-1:123456789012:key/abc"
  }

  expect_failures = [
    var.existing_attachment_s3_bucket_arn,
  ]
}

# An incomplete KMS key ARN (prefix only, no region/account/key) is rejected.
run "rejects_incomplete_kms_key_arn" {
  command = plan

  variables {
    existing_attachment_s3_bucket_arn         = "arn:aws:s3:::example-attachment-bucket"
    existing_attachment_s3_bucket_kms_key_arn = "arn:aws:kms:us-east-1"
  }

  expect_failures = [
    var.existing_attachment_s3_bucket_kms_key_arn,
  ]
}
