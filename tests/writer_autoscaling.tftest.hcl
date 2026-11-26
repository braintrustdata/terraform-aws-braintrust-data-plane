# Root-module plans and input validation for opt-in Brainstore writer autoscaling.

mock_provider "aws" {
  source = "./tests/mocks/aws"
}

mock_provider "random" {}

mock_provider "http" {
  source = "./tests/mocks/http"
}

variables {
  braintrust_org_name              = "test-org"
  primary_org_name                 = "test-org"
  deployment_name                  = "bt-writer-scaling"
  brainstore_license_key           = "test-license"
  enable_quarantine_vpc            = false
  brainstore_writer_instance_count = 3
}

run "writer_autoscaling_plans" {
  command = plan

  variables {
    brainstore_writer_min_capacity                 = 3
    brainstore_writer_max_capacity                 = 10
    brainstore_writer_target_compaction_queue_size = 20
    brainstore_writer_target_merge_loop_segments   = 300
  }

  assert {
    condition     = length(module.brainstore) == 1
    error_message = "Writer autoscaling should plan with the Brainstore module."
  }
}

run "writer_autoscaling_plans_in_existing_vpc" {
  command = plan

  variables {
    brainstore_writer_min_capacity = 3
    brainstore_writer_max_capacity = 10
    create_vpc                     = false
    existing_vpc_id                = "vpc-12345678"
    existing_private_subnet_1_id   = "subnet-11111111"
    existing_private_subnet_2_id   = "subnet-22222222"
    existing_private_subnet_3_id   = "subnet-33333333"
    existing_public_subnet_1_id    = "subnet-44444444"
  }
}

run "root_writer_autoscaling_rejects_missing_minimum" {
  command = plan

  variables {
    brainstore_writer_max_capacity = 5
  }

  expect_failures = [var.brainstore_writer_max_capacity]
}

run "root_writer_autoscaling_rejects_missing_maximum" {
  command = plan

  variables {
    brainstore_writer_min_capacity = 3
  }

  expect_failures = [var.brainstore_writer_max_capacity]
}

run "root_writer_autoscaling_rejects_inverted_bounds" {
  command = plan

  variables {
    brainstore_writer_min_capacity = 3
    brainstore_writer_max_capacity = 2
  }

  expect_failures = [var.brainstore_writer_max_capacity]
}

run "root_writer_autoscaling_rejects_zero_minimum" {
  command = plan

  variables {
    brainstore_writer_min_capacity = 0
    brainstore_writer_max_capacity = 4
  }

  expect_failures = [var.brainstore_writer_min_capacity]
}

run "root_writer_autoscaling_rejects_disabled_writer_pool" {
  command = plan

  variables {
    brainstore_writer_instance_count = 0
    brainstore_writer_min_capacity   = 1
    brainstore_writer_max_capacity   = 4
  }

  expect_failures = [var.brainstore_writer_max_capacity]
}

run "root_writer_autoscaling_rejects_invalid_targets" {
  command = plan

  variables {
    brainstore_writer_target_compaction_queue_size = 0
    brainstore_writer_target_merge_loop_segments   = -1
  }

  expect_failures = [
    var.brainstore_writer_target_compaction_queue_size,
    var.brainstore_writer_target_merge_loop_segments,
  ]
}
