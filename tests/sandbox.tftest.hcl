# Plan-mode smoke test shaped like examples/braintrust-data-plane-sandbox.
#
# Primary signal: plan succeeds with quarantine VPC off and brainstore still on.

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
  deployment_name                             = "bt-sandbox"
  brainstore_license_key                      = "test-license"
  enable_quarantine_vpc                       = false
  brainstore_instance_count                   = 1
  brainstore_writer_instance_count            = 1
  brainstore_fast_reader_instance_count       = 0
  skip_pg_for_brainstore_objects              = "all"
  DANGER_disable_database_deletion_protection = true
}

run "sandbox_plans" {
  command = plan

  assert {
    condition     = length(module.quarantine_vpc) == 0
    error_message = "sandbox mode should skip the quarantine VPC"
  }

  assert {
    condition     = length(module.services) == 1
    error_message = "sandbox mode should still create the services module"
  }

  assert {
    condition     = length(module.api_ecs) == 1
    error_message = "sandbox mode should still create the api_ecs module"
  }

  assert {
    condition     = length(module.brainstore) == 1
    error_message = "sandbox mode should create the brainstore module"
  }
}
