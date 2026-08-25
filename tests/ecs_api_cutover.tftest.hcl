# Plan-mode smoke test for the v6 ECS API traffic cutover (enable_ecs_api = true).
#
# Primary signal: plan succeeds with Lambdas and ECS API both present for rollback.

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
  enable_ecs_api         = true
}

run "ecs_api_cutover_plans" {
  command = plan

  assert {
    condition     = length(module.api_ecs) == 1
    error_message = "cutover path should keep the api_ecs module"
  }

  assert {
    condition     = length(module.services) == 1
    error_message = "cutover path should keep Lambdas for rollback"
  }

  assert {
    condition     = length(module.ingress) == 1
    error_message = "cutover path should keep ingress for CloudFront routing"
  }
}
