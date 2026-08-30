# Root-module regression fixture for warm API ECS services before traffic cutover.

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
  enable_ecs_api         = false
}

run "seed_mocked_warm_root_state" {
  command = apply
}

run "force_warm_root_api_ecs_replacements" {
  command = plan

  plan_options {
    refresh = false
    replace = [
      module.api_ecs[0].aws_ecs_service.braintrust_api,
      module.api_ecs[0].aws_ecs_service.braintrust_api_ingest,
      module.api_ecs[0].aws_ecs_service.braintrust_api_background,
    ]
  }
}
