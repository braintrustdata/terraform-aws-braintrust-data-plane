# Negative tests for known-invalid variable combinations.
# These should fail variable validation, not plan evaluation.

mock_provider "aws" {
  source = "./tests/mocks/aws"
}

mock_provider "random" {}

variables {
  braintrust_org_name                         = "test-org"
  primary_org_name                            = "test-org"
  deployment_name                             = "bt-test"
  brainstore_license_key                      = "test-license"
  DANGER_disable_database_deletion_protection = true
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
