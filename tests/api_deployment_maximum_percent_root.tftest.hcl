# Root inputs for API ECS deployment_maximum_percent apply the same
# validation as the api-ecs module.

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
  enable_ecs_api         = true
}

run "accepts_lower_deployment_maximum_percent" {
  command = plan

  variables {
    braintrust_api_deployment_maximum_percent            = 150
    braintrust_api_ingest_deployment_maximum_percent     = 150
    braintrust_api_background_deployment_maximum_percent = 150
  }

  assert {
    condition     = length(module.api_ecs) == 1
    error_message = "ECS mode must plan the api_ecs module with lower deployment_maximum_percent values."
  }
}

run "rejects_root_deployment_maximum_percent_above_200" {
  command = plan

  variables {
    braintrust_api_deployment_maximum_percent = 250
  }

  expect_failures = [var.braintrust_api_deployment_maximum_percent]
}

run "rejects_root_deployment_maximum_percent_without_extra_task" {
  command = plan

  variables {
    braintrust_api_ingest_min_count                  = 4
    braintrust_api_ingest_deployment_maximum_percent = 120
  }

  expect_failures = [var.braintrust_api_ingest_deployment_maximum_percent]
}
