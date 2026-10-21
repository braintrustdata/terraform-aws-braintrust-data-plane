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

run "automation_writer_with_ecs_cutover_plans" {
  command = plan

  variables {
    enable_ecs_api = true
  }
}

run "automation_writer_custom_targets_plan_in_existing_vpc" {
  command = plan

  variables {
    brainstore_automation_writer_target_cpu_utilization    = 55
    brainstore_automation_writer_target_memory_utilization = 65
    create_vpc                                             = false
    existing_vpc_id                                        = "vpc-12345678"
    existing_private_subnet_1_id                           = "subnet-11111111"
    existing_private_subnet_2_id                           = "subnet-22222222"
    existing_private_subnet_3_id                           = "subnet-33333333"
    existing_public_subnet_1_id                            = "subnet-44444444"
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

run "root_automation_writer_rejects_invalid_targets" {
  command = plan

  variables {
    brainstore_automation_writer_target_cpu_utilization    = 0
    brainstore_automation_writer_target_memory_utilization = 101
  }

  expect_failures = [
    var.brainstore_automation_writer_target_cpu_utilization,
    var.brainstore_automation_writer_target_memory_utilization,
  ]
}
