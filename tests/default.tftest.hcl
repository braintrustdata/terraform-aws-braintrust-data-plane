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
  braintrust_org_name    = "test-org"
  primary_org_name       = "test-org"
  deployment_name        = "bt-test"
  brainstore_license_key = "test-license"
  enable_quarantine_vpc  = true
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

  assert {
    condition     = length(module.brainstore_deployment) == 1 && toset([for fleet in module.brainstore[0].deployment_fleets : fleet.role]) == toset(["reader", "writer", "fast-reader"])
    error_message = "The default rollout gate must include all three Brainstore fleets."
  }

  assert {
    condition     = module.main_vpc[0].flow_log_id == null
    error_message = "VPC Flow Logs should be disabled by default"
  }

  assert {
    condition     = module.quarantine_vpc[0].flow_log_id == null
    error_message = "quarantine VPC Flow Logs should be disabled by default"
  }
}

run "reader_only_plans" {
  command = plan
  variables {
    brainstore_writer_instance_count      = 0
    brainstore_fast_reader_instance_count = 0
  }
  assert {
    condition     = length(module.brainstore[0].deployment_fleets) == 1 && module.brainstore[0].deployment_fleets[0].role == "reader"
    error_message = "Disabled writer and fast-reader fleets must not be included in the rollout request."
  }
}
