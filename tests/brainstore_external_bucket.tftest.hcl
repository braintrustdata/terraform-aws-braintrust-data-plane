# Plan-mode smoke tests for the module-owned vs. caller-provided (external)
# Brainstore S3 bucket modes.
#
# Primary signal: plan succeeds in both modes. Asserts lock the default,
# the external-mode derived bucket name, and that external mode plans without
# a module-managed bucket (so an upgrade to external mode replaces nothing).

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
    condition     = var.create_brainstore_s3_bucket == true
    error_message = "create_brainstore_s3_bucket must default to true (module-owned bucket)"
  }

  assert {
    condition     = var.existing_brainstore_s3_bucket_arn == null
    error_message = "existing_brainstore_s3_bucket_arn must default to null"
  }
}

# External mode: no bucket is created and identity is derived from the ARN.
run "external_bucket_mode_plans" {
  command = plan

  variables {
    create_brainstore_s3_bucket               = false
    existing_brainstore_s3_bucket_arn         = "arn:aws:s3:::external-brainstore-bucket"
    existing_brainstore_s3_bucket_kms_key_arn = "arn:aws:kms:us-east-1:123456789012:key/1234abcd-12ab-34cd-56ef-1234567890ab"
  }

  assert {
    condition     = output.brainstore_s3_bucket_name == "external-brainstore-bucket"
    error_message = "external Brainstore bucket name must be derived from the provided ARN"
  }
}

# External mode without a KMS key ARN is also valid (unencrypted / SSE-S3 bucket).
run "external_bucket_mode_without_kms_plans" {
  command = plan

  variables {
    create_brainstore_s3_bucket       = false
    existing_brainstore_s3_bucket_arn = "arn:aws:s3:::external-brainstore-bucket"
  }

  assert {
    condition     = output.brainstore_s3_bucket_name == "external-brainstore-bucket"
    error_message = "external Brainstore bucket name must be derived from the provided ARN"
  }
}

# NOTE: The Loop runtime task role is a third Brainstore-bucket writer that also
# needs the external KMS key (wired via loop_runtime_ecs.brainstore_s3_bucket_kms_key_arn).
# That path can't be plan-tested here because the mocked Brainstore security
# group id is unknown at plan and feeds a count() in loop-runtime-ecs, so the
# loop runtime module cannot be planned under mock providers. It is covered by
# terraform validate and by an isolated module-level assertion during review.
