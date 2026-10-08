# Root-module smoke plans cover wiring to storage and both managed VPCs.
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
  main_vpc_flow_log = {
    enabled = true
  }
  quarantine_vpc_flow_log = {
    enabled = true
  }
}

run "managed_by_default" {
  command = plan

  assert {
    condition     = var.manage_s3_public_access_block
    error_message = "Public access block management must remain enabled by default."
  }
}

run "new_deployment_opt_out" {
  command = plan

  variables {
    manage_s3_public_access_block = false
  }

  assert {
    condition = (
      module.main_vpc[0].flow_log_enabled &&
      module.quarantine_vpc[0].flow_log_enabled
    )
    error_message = "Opt-out must not disable either VPC's flow logging."
  }
}
