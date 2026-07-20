# Plan-mode smoke test for the default (non-external-EKS) deployment.
#
# Primary signal: plan succeeds. Asserts only lock the module count matrix.

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
  DANGER_disable_database_deletion_protection = true
}

run "default_plans" {
  command = plan

  assert {
    condition     = length(module.services) == 1
    error_message = "default mode should create the services module"
  }

  assert {
    condition     = length(module.api_ecs) == 1
    error_message = "default mode should create the api_ecs module"
  }

  assert {
    condition     = length(module.ingress) == 1
    error_message = "default mode should create the ingress module"
  }

  assert {
    condition     = length(module.brainstore) == 1
    error_message = "default mode should create the brainstore module"
  }
}
