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
  assert {
    condition     = var.loop_runtime_sandbox_egress_mode == "restricted"
    error_message = "MicroVM egress must default to restricted."
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
