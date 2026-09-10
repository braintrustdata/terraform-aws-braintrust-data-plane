# Plan-mode tests for optional VPC Encryption Control.
# Primary signal: plan succeeds. Resource IDs are unknown until apply, so assert
# the plan-time mode mapping and enabled flags instead.

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

run "monitoring_maps_to_monitor" {
  command = plan

  variables {
    main_vpc_encryption_control = "monitoring"
  }

  assert {
    condition     = module.main_vpc[0].encryption_control_enabled
    error_message = "monitoring should enable VPC Encryption Control on the main VPC"
  }

  assert {
    condition     = module.main_vpc[0].encryption_control_mode == "monitor"
    error_message = "monitoring should map to the AWS \"monitor\" mode"
  }

  assert {
    condition     = module.quarantine_vpc[0].encryption_control_mode == null
    error_message = "quarantine VPC Encryption Control should stay disabled when only the main VPC is set"
  }
}

run "enforced_maps_to_enforce" {
  command = plan

  variables {
    quarantine_vpc_encryption_control = "enforced"
  }

  assert {
    condition     = module.quarantine_vpc[0].encryption_control_enabled
    error_message = "enforced should enable VPC Encryption Control on the quarantine VPC"
  }

  assert {
    condition     = module.quarantine_vpc[0].encryption_control_mode == "enforce"
    error_message = "enforced should map to the AWS \"enforce\" mode"
  }

  assert {
    condition     = module.main_vpc[0].encryption_control_mode == null
    error_message = "main VPC Encryption Control should stay disabled when only the quarantine VPC is set"
  }
}
