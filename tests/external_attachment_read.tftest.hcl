# Plan-mode tests for read-only access to caller-owned buckets that traces link
# to as external attachments (external_attachment_s3_bucket_arns /
# external_attachment_kms_key_arns).

mock_provider "aws" {
  source = "./tests/mocks/aws"
  mock_data "aws_partition" {
    defaults = { partition = "aws" }
  }
}

variables {
  deployment_name                = "bt-test"
  vpc_id                         = "vpc-12345678"
  kms_key_arn                    = "arn:aws:kms:us-east-1:123456789012:key/00000000-0000-0000-0000-000000000000"
  brainstore_s3_bucket_arn       = "arn:aws:s3:::bt-test-brainstore"
  database_secret_arn            = "arn:aws:secretsmanager:us-east-1:123456789012:secret:bt-test-database"
  code_bundle_s3_bucket_arn      = "arn:aws:s3:::bt-test-code-bundles"
  lambda_responses_s3_bucket_arn = "arn:aws:s3:::bt-test-lambda-responses"
  enable_quarantine_vpc          = false
}

run "default_creates_no_external_attachment_grant" {
  command = plan
  module { source = "./modules/services-common" }

  assert {
    condition     = length(aws_iam_role_policy.api_handler_external_attachment_read) == 0
    error_message = "Default must not broaden API role permissions."
  }
}

run "grants_object_read_only" {
  command = plan
  module { source = "./modules/services-common" }

  variables {
    external_attachment_s3_bucket_arns = ["arn:aws:s3:::example-a", "arn:aws:s3:::example-b"]
  }

  assert {
    condition     = length(jsondecode(aws_iam_role_policy.api_handler_external_attachment_read[0].policy).Statement) == 1
    error_message = "Unencrypted buckets must not grant KMS access."
  }

  assert {
    condition     = jsondecode(aws_iam_role_policy.api_handler_external_attachment_read[0].policy).Statement[0].Action == ["s3:GetObject"]
    error_message = "The grant must be object reads only, with no list or write access."
  }

  assert {
    condition     = jsondecode(aws_iam_role_policy.api_handler_external_attachment_read[0].policy).Statement[0].Resource == ["arn:aws:s3:::example-a/*", "arn:aws:s3:::example-b/*"]
    error_message = "The grant must cover the objects of exactly the listed buckets."
  }
}

run "grants_decrypt_through_s3_only" {
  command = plan
  module { source = "./modules/services-common" }

  variables {
    external_attachment_s3_bucket_arns = ["arn:aws:s3:::example-a"]
    external_attachment_kms_key_arns   = ["arn:aws:kms:us-east-1:210987654321:key/11111111-1111-1111-1111-111111111111"]
  }

  assert {
    condition     = jsondecode(aws_iam_role_policy.api_handler_external_attachment_read[0].policy).Statement[1].Action == ["kms:Decrypt"]
    error_message = "Encrypted buckets must grant decrypt only."
  }

  assert {
    condition     = jsondecode(aws_iam_role_policy.api_handler_external_attachment_read[0].policy).Statement[1].Condition.StringLike["kms:ViaService"] == "s3.*.amazonaws.com"
    error_message = "Decrypt must be limited to requests made through S3."
  }
}

run "rejects_non_s3_bucket_arn" {
  command = plan

  variables {
    braintrust_org_name                = "test-org"
    primary_org_name                   = "test-org"
    brainstore_license_key             = "test-license"
    external_attachment_s3_bucket_arns = ["arn:aws:kms:us-east-1:123456789012:key/abc"]
  }

  expect_failures = [
    var.external_attachment_s3_bucket_arns,
  ]
}

run "rejects_kms_without_bucket" {
  command = plan

  variables {
    braintrust_org_name              = "test-org"
    primary_org_name                 = "test-org"
    brainstore_license_key           = "test-license"
    external_attachment_kms_key_arns = ["arn:aws:kms:us-east-1:123456789012:key/00000000-0000-0000-0000-000000000000"]
  }

  expect_failures = [
    var.external_attachment_kms_key_arns,
  ]
}
