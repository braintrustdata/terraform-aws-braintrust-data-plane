# Plan-mode smoke test for private AI gateway infra (create_ai_gateway = true).
#
# Primary signal: plan succeeds for the infra-only first step of the gateway cutover.

mock_provider "aws" {
  source = "./tests/mocks/aws"
}

mock_provider "random" {}

mock_provider "http" {
  source = "./tests/mocks/http"
}

variables {
  braintrust_org_name                         = "test-org"
  primary_org_name                            = "test-org"
  deployment_name                             = "bt-test"
  brainstore_license_key                      = "test-license"
  enable_quarantine_vpc                       = true
  create_ai_gateway                           = true
  enable_ai_gateway                           = false
  DANGER_disable_database_deletion_protection = true
}

run "ai_gateway_plans" {
  command = plan

  assert {
    condition     = length(module.gateway_ecs) == 1
    error_message = "create_ai_gateway should create the gateway_ecs module"
  }

  assert {
    condition     = length(module.ecs) == 1
    error_message = "create_ai_gateway should create the shared ECS cluster"
  }

  assert {
    condition     = length(module.api_ecs) == 1
    error_message = "standard deployments should still create api_ecs alongside the gateway"
  }
}
