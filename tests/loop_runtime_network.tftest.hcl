mock_provider "aws" {
  source = "./tests/mocks/aws"
  mock_data "aws_subnet" {
    defaults = { vpc_id = "vpc-0123456789abcdef0" }
  }
  mock_data "aws_partition" {
    defaults = { partition = "aws" }
  }
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
  enable_loop_runtime    = true
}

run "loop_private_endpoint" {
  command = plan

  assert {
    condition     = length(module.loop_runtime_ecs) == 1 && length(module.loop_runtime_sandbox_aws_microvm) == 1
    error_message = "Loop must create the runtime and MicroVM modules."
  }
}

run "loop_with_existing_sandbox_vpc" {
  command = plan
  variables {
    loop_runtime_sandbox_existing_vpc_id              = "vpc-0123456789abcdef0"
    loop_runtime_sandbox_existing_private_subnet_1_id = "subnet-0123456789abcdef0"
    loop_runtime_sandbox_existing_private_subnet_2_id = "subnet-0123456789abcdef1"
    loop_runtime_sandbox_existing_private_subnet_3_id = "subnet-0123456789abcdef2"
  }
}

# The fresh-deployment ordering regression is checked by
# scripts/check-loop-network-dependencies. Mocked plans cannot establish that a
# Lambda invocation actually has PostgreSQL connectivity at invocation time.
run "loop_with_private_gateway" {
  command = plan
  variables {
    create_ai_gateway = true
    enable_ai_gateway = true
  }
}

run "loop_disabled_with_private_gateway" {
  command = plan
  variables {
    enable_loop_runtime = false
    create_ai_gateway   = true
    enable_ai_gateway   = true
  }

  assert {
    condition     = length(module.loop_runtime_ecs) == 0 && length(module.gateway_ecs) == 1
    error_message = "Disabling Loop must retain the independently enabled gateway."
  }
}

run "rejects_empty_existing_sandbox_subnet_1_id" {
  command = plan
  variables {
    loop_runtime_sandbox_existing_vpc_id              = "vpc-0123456789abcdef0"
    loop_runtime_sandbox_existing_private_subnet_1_id = ""
    loop_runtime_sandbox_existing_private_subnet_2_id = "subnet-0123456789abcdef1"
    loop_runtime_sandbox_existing_private_subnet_3_id = "subnet-0123456789abcdef2"
  }
  expect_failures = [var.loop_runtime_sandbox_existing_private_subnet_1_id]
}

run "rejects_empty_existing_sandbox_subnet_2_id" {
  command = plan
  variables {
    loop_runtime_sandbox_existing_vpc_id              = "vpc-0123456789abcdef0"
    loop_runtime_sandbox_existing_private_subnet_1_id = "subnet-0123456789abcdef0"
    loop_runtime_sandbox_existing_private_subnet_2_id = " "
    loop_runtime_sandbox_existing_private_subnet_3_id = "subnet-0123456789abcdef2"
  }
  expect_failures = [var.loop_runtime_sandbox_existing_private_subnet_2_id]
}

run "rejects_empty_existing_sandbox_subnet_3_id" {
  command = plan
  variables {
    loop_runtime_sandbox_existing_vpc_id              = "vpc-0123456789abcdef0"
    loop_runtime_sandbox_existing_private_subnet_1_id = "subnet-0123456789abcdef0"
    loop_runtime_sandbox_existing_private_subnet_2_id = "subnet-0123456789abcdef1"
    loop_runtime_sandbox_existing_private_subnet_3_id = "  "
  }
  expect_failures = [var.loop_runtime_sandbox_existing_private_subnet_3_id]
}

run "rejects_internet_sandbox_egress" {
  command = plan
  variables {
    loop_runtime_sandbox_egress_mode = "internet"
  }
  expect_failures = [var.loop_runtime_sandbox_egress_mode]
}

run "accepts_deprecated_restricted_sandbox_egress" {
  command = plan
  variables {
    loop_runtime_sandbox_egress_mode = "restricted"
  }
}
