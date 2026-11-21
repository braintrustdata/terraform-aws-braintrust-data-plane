# Root-module plans and input validation for opt-in Brainstore reader autoscaling.

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
  deployment_name        = "bt-reader-scaling"
  brainstore_license_key = "test-license"
  enable_quarantine_vpc  = false
}

run "reader_autoscaling_plans" {
  command = plan

  variables {
    brainstore_reader_min_capacity           = 2
    brainstore_reader_max_capacity           = 10
    brainstore_reader_target_cpu_utilization = 60
  }

  assert {
    condition = (
      length(module.brainstore_deployment) == 1 &&
      module.brainstore[0].deployment_fleets[0].min_capacity == 2 &&
      module.brainstore[0].deployment_fleets[0].max_capacity == 10
    )
    error_message = "The root deployment gate must receive the reader bounds."
  }
}

run "reader_autoscaling_plans_in_existing_vpc" {
  command = plan

  variables {
    brainstore_reader_min_capacity = 2
    brainstore_reader_max_capacity = 10
    create_vpc                     = false
    existing_vpc_id                = "vpc-12345678"
    existing_private_subnet_1_id   = "subnet-11111111"
    existing_private_subnet_2_id   = "subnet-22222222"
    existing_private_subnet_3_id   = "subnet-33333333"
    existing_public_subnet_1_id    = "subnet-44444444"
  }
}

run "root_reader_autoscaling_rejects_missing_minimum" {
  command = plan

  variables {
    brainstore_reader_max_capacity = 5
  }

  expect_failures = [var.brainstore_reader_max_capacity]
}

run "root_reader_autoscaling_rejects_missing_maximum" {
  command = plan

  variables {
    brainstore_reader_min_capacity = 3
  }

  expect_failures = [var.brainstore_reader_max_capacity]
}

run "root_reader_autoscaling_rejects_inverted_bounds" {
  command = plan

  variables {
    brainstore_reader_min_capacity = 3
    brainstore_reader_max_capacity = 2
  }

  expect_failures = [var.brainstore_reader_max_capacity]
}

run "root_reader_autoscaling_rejects_zero_minimum" {
  command = plan

  variables {
    brainstore_reader_min_capacity = 0
    brainstore_reader_max_capacity = 4
  }

  expect_failures = [var.brainstore_reader_min_capacity]
}

run "root_reader_autoscaling_rejects_invalid_target" {
  command = plan

  variables {
    brainstore_reader_target_cpu_utilization = 101
  }

  expect_failures = [var.brainstore_reader_target_cpu_utilization]
}
