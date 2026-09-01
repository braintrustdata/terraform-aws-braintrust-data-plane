# Negative tests for known-invalid variable combinations.
# These should fail variable validation, not plan evaluation.

mock_provider "aws" {
  source = "./tests/mocks/aws"
}

mock_provider "random" {}

variables {
  braintrust_org_name    = "test-org"
  primary_org_name       = "test-org"
  deployment_name        = "bt-test"
  brainstore_license_key = "test-license"
}

run "rejects_ecs_api_with_external_eks" {
  command = plan

  variables {
    use_deployment_mode_external_eks = true
    enable_ecs_api                   = true
  }

  expect_failures = [
    var.enable_ecs_api,
  ]
}

run "rejects_enable_ai_gateway_without_create" {
  command = plan

  variables {
    create_ai_gateway = false
    enable_ai_gateway = true
  }

  expect_failures = [
    var.enable_ai_gateway,
  ]
}

run "rejects_external_brainstore_bucket_without_arn" {
  command = plan

  variables {
    create_brainstore_s3_bucket       = false
    existing_brainstore_s3_bucket_arn = null
  }

  expect_failures = [
    var.existing_brainstore_s3_bucket_arn,
  ]
}

run "rejects_external_brainstore_arn_when_module_owned" {
  command = plan

  variables {
    create_brainstore_s3_bucket       = true
    existing_brainstore_s3_bucket_arn = "arn:aws:s3:::some-external-bucket"
  }

  expect_failures = [
    var.existing_brainstore_s3_bucket_arn,
  ]
}

run "rejects_external_brainstore_kms_key_without_arn" {
  command = plan

  variables {
    existing_brainstore_s3_bucket_kms_key_arn = "arn:aws:kms:us-east-1:123456789012:key/1234abcd-12ab-34cd-56ef-1234567890ab"
  }

  expect_failures = [
    var.existing_brainstore_s3_bucket_kms_key_arn,
  ]
}
