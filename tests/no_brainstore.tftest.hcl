# Plan-mode smoke test for enable_brainstore = false.
#
# Primary signal: plan succeeds when Brainstore ASGs are skipped but API ECS remains.

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
  enable_brainstore                           = false
  enable_quarantine_vpc                       = true
  DANGER_disable_database_deletion_protection = true
}

run "no_brainstore_plans" {
  command = plan

  assert {
    condition     = length(module.brainstore) == 0
    error_message = "enable_brainstore=false should skip the brainstore module"
  }

  assert {
    condition     = length(module.api_ecs) == 1
    error_message = "enable_brainstore=false should still create the api_ecs module"
  }

  assert {
    condition     = length(module.services) == 1
    error_message = "enable_brainstore=false should still create the services module"
  }
}
