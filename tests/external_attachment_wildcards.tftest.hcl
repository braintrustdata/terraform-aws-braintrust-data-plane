# Plan-mode validation coverage for external attachment bucket and KMS wildcards.

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

run "accepts_ephemeral_bucket_prefix_and_all_keys_in_region_account" {
  command = plan

  variables {
    external_attachment_s3_bucket_arns         = ["arn:aws:s3:::example-*"]
    external_attachment_s3_bucket_kms_key_arns = ["arn:aws:kms:us-east-1:123456789012:key/*"]
  }
}

# The first pattern could span bucket boundaries after the module appends /*;
# the remaining patterns are not a literal trailing bucket-prefix wildcard.
run "rejects_unsafe_bucket_wildcard_patterns" {
  command = plan

  variables {
    external_attachment_s3_bucket_arns = [
      "arn:aws:s3:::app-*-attachments",
      "arn:aws:s3:::*-attachments",
      "arn:aws:s3:::key/prefix-*",
      "arn:aws:s3:::example-?",
    ]
  }

  expect_failures = [
    var.external_attachment_s3_bucket_arns,
  ]
}

run "rejects_key_prefix_wildcard" {
  command = plan

  variables {
    external_attachment_s3_bucket_arns         = ["arn:aws:s3:::example-attachments"]
    external_attachment_s3_bucket_kms_key_arns = ["arn:aws:kms:us-east-1:123456789012:key/prefix-*"]
  }

  expect_failures = [
    var.external_attachment_s3_bucket_kms_key_arns,
  ]
}

run "rejects_kms_wildcard_region" {
  command = plan

  variables {
    external_attachment_s3_bucket_arns         = ["arn:aws:s3:::example-attachments"]
    external_attachment_s3_bucket_kms_key_arns = ["arn:aws:kms:*:123456789012:key/*"]
  }

  expect_failures = [
    var.external_attachment_s3_bucket_kms_key_arns,
  ]
}

run "rejects_kms_wildcard_account" {
  command = plan

  variables {
    external_attachment_s3_bucket_arns         = ["arn:aws:s3:::example-attachments"]
    external_attachment_s3_bucket_kms_key_arns = ["arn:aws:kms:us-east-1:*:key/*"]
  }

  expect_failures = [
    var.external_attachment_s3_bucket_kms_key_arns,
  ]
}
