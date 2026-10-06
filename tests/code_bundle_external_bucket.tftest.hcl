# Plan-mode smoke tests for the module-owned vs. caller-provided (external)
# code bundle S3 bucket modes.

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
}

# Module-owned mode is the default and must stay that way for existing stacks.
run "module_owned_is_default" {
  command = plan

  assert {
    condition     = var.create_code_bundle_s3_bucket == true
    error_message = "create_code_bundle_s3_bucket must default to true (module-owned bucket)"
  }

  assert {
    condition     = var.existing_code_bundle_s3_bucket_arn == null
    error_message = "existing_code_bundle_s3_bucket_arn must default to null"
  }
}

# External mode: no bucket is created and identity is derived from the ARN.
run "external_bucket_mode_plans" {
  command = plan

  variables {
    create_code_bundle_s3_bucket       = false
    existing_code_bundle_s3_bucket_arn = "arn:aws:s3:::external-code-bundle-bucket"
  }

  assert {
    condition     = output.code_bundle_s3_bucket_name == "external-code-bundle-bucket"
    error_message = "external code bundle bucket name must be derived from the provided ARN"
  }
}

run "rejects_missing_arn_when_not_created" {
  command = plan

  variables {
    create_code_bundle_s3_bucket = false
  }

  expect_failures = [var.existing_code_bundle_s3_bucket_arn]
}

run "rejects_arn_when_created" {
  command = plan

  variables {
    existing_code_bundle_s3_bucket_arn = "arn:aws:s3:::external-code-bundle-bucket"
  }

  expect_failures = [var.existing_code_bundle_s3_bucket_arn]
}

run "rejects_non_bucket_arn" {
  command = plan

  variables {
    create_code_bundle_s3_bucket       = false
    existing_code_bundle_s3_bucket_arn = "external-code-bundle-bucket"
  }

  expect_failures = [var.existing_code_bundle_s3_bucket_arn]
}
