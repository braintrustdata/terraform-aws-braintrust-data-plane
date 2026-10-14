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

run "managed_vpc_keeps_three_subnets" {
  command = plan

  assert {
    condition     = length(module.main_vpc[0].private_subnet_ids) == 3 && length(module.quarantine_vpc[0].private_subnet_ids) == 3
    error_message = "A three-zone region must keep private subnet 3 in both VPCs."
  }
}

run "managed_vpc_with_two_zones" {
  command = plan

  override_data {
    target = data.aws_availability_zones.available
    values = { names = ["us-west-1a", "us-west-1c"] }
  }

  assert {
    condition     = length(module.main_vpc[0].private_subnet_ids) == 2 && length(module.quarantine_vpc[0].private_subnet_ids) == 2
    error_message = "A two-zone region must create two private subnets in both VPCs."
  }

  assert {
    condition     = output.main_vpc_private_subnet_3_id == null && output.quarantine_private_subnet_3_id == null
    error_message = "A two-zone region must omit private subnet 3."
  }
}

run "existing_vpc_with_two_subnets" {
  command = plan

  variables {
    create_vpc                              = false
    existing_vpc_id                         = "vpc-12345678"
    existing_private_subnet_1_id            = "subnet-11111111"
    existing_private_subnet_2_id            = "subnet-22222222"
    existing_public_subnet_1_id             = "subnet-44444444"
    existing_quarantine_vpc_id              = "vpc-12345679"
    existing_quarantine_private_subnet_1_id = "subnet-55555555"
    existing_quarantine_private_subnet_2_id = "subnet-66666666"
  }

  override_data {
    target = data.aws_availability_zones.available
    values = { names = ["us-west-1a", "us-west-1c"] }
  }

  assert {
    condition     = length(module.main_vpc) == 0 && length(module.quarantine_vpc) == 0
    error_message = "A bring-your-own VPC must not create module VPCs."
  }

  assert {
    condition     = output.main_vpc_private_subnet_3_id == null && output.quarantine_private_subnet_3_id == null
    error_message = "A two-zone bring-your-own VPC must plan without a third subnet."
  }
}

run "rejects_duplicate_existing_subnet" {
  command = plan

  variables {
    create_vpc                   = false
    existing_vpc_id              = "vpc-12345678"
    existing_private_subnet_1_id = "subnet-11111111"
    existing_private_subnet_2_id = "subnet-22222222"
    existing_private_subnet_3_id = "subnet-22222222"
    existing_public_subnet_1_id  = "subnet-44444444"
    enable_quarantine_vpc        = false
  }

  expect_failures = [var.existing_private_subnet_3_id]
}

run "rejects_missing_subnet_3_in_three_zones" {
  command = plan

  variables {
    create_vpc                   = false
    existing_vpc_id              = "vpc-12345678"
    existing_private_subnet_1_id = "subnet-11111111"
    existing_private_subnet_2_id = "subnet-22222222"
    existing_public_subnet_1_id  = "subnet-44444444"
    enable_quarantine_vpc        = false
  }

  expect_failures = [terraform_data.network_zone_requirements]
}

run "rejects_single_zone" {
  command = plan

  override_data {
    target = data.aws_availability_zones.available
    values = { names = ["us-west-1a"] }
  }

  expect_failures = [terraform_data.network_zone_requirements]
}

run "rejects_subnet_3_in_two_zones" {
  command = plan

  variables {
    create_vpc                   = false
    existing_vpc_id              = "vpc-12345678"
    existing_private_subnet_1_id = "subnet-11111111"
    existing_private_subnet_2_id = "subnet-22222222"
    existing_private_subnet_3_id = "subnet-33333333"
    existing_public_subnet_1_id  = "subnet-44444444"
    enable_quarantine_vpc        = false
  }

  override_data {
    target = data.aws_availability_zones.available
    values = { names = ["us-west-1a", "us-west-1c"] }
  }

  expect_failures = [terraform_data.network_zone_requirements]
}
