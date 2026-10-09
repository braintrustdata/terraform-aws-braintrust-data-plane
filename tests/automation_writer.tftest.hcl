# Plan-mode smoke test for an enabled dedicated Brainstore automation writer pool.

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
  deployment_name                             = "bt-automation"
  brainstore_license_key                      = "test-license"
  enable_quarantine_vpc                       = false
  brainstore_automation_writer_instance_count = 2
}

run "automation_writer_plans" {
  command = plan

  assert {
    condition     = length(module.brainstore) == 1
    error_message = "an enabled automation writer pool should plan with the Brainstore module"
  }
}

run "automation_writer_queries_plans" {
  command = plan

  variables {
    enable_brainstore_automation_writer_queries = true
  }
}

run "automation_writer_queries_with_ecs_cutover_plans" {
  command = plan

  variables {
    enable_brainstore_automation_writer_queries = true
    enable_ecs_api                              = true
  }
}

run "automation_writer_queries_require_a_pool" {
  command = plan

  variables {
    enable_brainstore_automation_writer_queries = true
    brainstore_automation_writer_instance_count = 0
  }

  expect_failures = [var.enable_brainstore_automation_writer_queries]
}
