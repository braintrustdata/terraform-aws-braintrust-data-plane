# Plan-mode smoke test for an enabled dedicated Brainstore automation writer pool.

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
  deployment_name        = "bt-automation"
  brainstore_license_key = "test-license"
  enable_quarantine_vpc  = false
}

run "automation_writer_plans" {
  command = plan

  assert {
    condition     = length(module.brainstore) == 1 && var.brainstore_automation_writer_instance_count == 2
    error_message = "an enabled automation writer pool should plan with the Brainstore module"
  }
}

run "automation_writer_with_ecs_cutover_plans" {
  command = plan

  variables {
    enable_ecs_api = true
  }
}

run "disabled_automation_writer_plans" {
  command = plan

  variables {
    brainstore_automation_writer_instance_count = 0
  }

  assert {
    condition     = module.brainstore[0].automation_writer_dns_name == null
    error_message = "A disabled automation writer pool must not expose a query endpoint."
  }
}
