# Plan-mode smoke tests for use_deployment_mode_external_eks.
#
# Primary signal: plan succeeds with services/api_ecs/ingress/brainstore skipped.

mock_provider "aws" {
  source = "./tests/mocks/aws"
}

mock_provider "random" {}

variables {
  braintrust_org_name              = "test-org"
  primary_org_name                 = "test-org"
  deployment_name                  = "bt-test"
  brainstore_license_key           = "test-license"
  use_deployment_mode_external_eks = true
  enable_quarantine_vpc            = true
}

run "external_eks_plans" {
  command = plan

  assert {
    condition     = length(module.services) == 0
    error_message = "external EKS mode should skip the services module"
  }

  assert {
    condition     = length(module.api_ecs) == 0
    error_message = "external EKS mode should skip the api_ecs module"
  }

  assert {
    condition     = length(module.ingress) == 0
    error_message = "external EKS mode should skip the ingress module"
  }

  assert {
    condition     = length(module.brainstore) == 0
    error_message = "external EKS mode should skip the brainstore module"
  }
}
