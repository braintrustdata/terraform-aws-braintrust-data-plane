mock_provider "aws" {
  source = "./tests/mocks/aws"
  mock_data "aws_partition" {
    defaults = { partition = "aws" }
  }
  mock_data "aws_subnet" {
    defaults = { vpc_id = "vpc-0123456789abcdef0" }
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

run "lambda_only_by_default" {
  command = plan
  assert {
    condition = (
      length(module.sandbox_service) == 0 &&
      length(module.loop_runtime_sandbox_aws_microvm) == 1 &&
      length(module.loop_runtime_ecs) == 1 &&
      local.loop_runtime_version == "v2.17.0"
    )
    error_message = "Existing Loop deployments must retain their Lambda backend and runtime release by default."
  }
}

run "service_alongside_lambda_in_managed_vpc" {
  command = plan
  variables {
    create_sandbox_service = true
  }
  assert {
    condition = (
      length(module.sandbox_service) == 1 &&
      length(module.loop_runtime_sandbox_aws_microvm) == 1 &&
      length(module.loop_runtime_ecs) == 1 &&
      local.loop_runtime_version == jsondecode(file("./modules/sandbox-service/VERSIONS.json"))["loop-runtime"] &&
      length(aws_vpc_security_group_egress_rule.sandbox_workers_to_loop_egress_gateway) == 1
    )
    error_message = "Sandbox Service must add one service without removing Lambda or duplicating Loop Runtime."
  }
}

run "service_alongside_lambda_in_existing_vpc" {
  command = plan
  variables {
    create_sandbox_service       = true
    create_vpc                   = false
    existing_vpc_id              = "vpc-0123456789abcdef0"
    existing_private_subnet_1_id = "subnet-0123456789abcdef0"
    existing_private_subnet_2_id = "subnet-0123456789abcdef1"
    existing_private_subnet_3_id = "subnet-0123456789abcdef2"
    existing_public_subnet_1_id  = "subnet-0123456789abcdef3"
  }
  assert {
    condition = (
      length(module.main_vpc) == 0 &&
      length(module.sandbox_service) == 1 &&
      local.main_vpc_private_subnet_ids == ["subnet-0123456789abcdef0", "subnet-0123456789abcdef1", "subnet-0123456789abcdef2"]
    )
    error_message = "Sandbox Service must reuse the supplied main VPC and all three private subnets."
  }
}

run "explicit_runtime_override_remains_supported" {
  command = plan
  variables {
    create_sandbox_service        = true
    loop_runtime_version_override = "compatible-custom-release"
  }
  assert {
    condition     = local.loop_runtime_version == "compatible-custom-release"
    error_message = "Sandbox Service must preserve explicit compatible Loop Runtime overrides."
  }
}

run "rejects_service_without_loop" {
  command = plan
  variables {
    create_sandbox_service = true
    enable_loop_runtime    = false
  }
  expect_failures = [var.create_sandbox_service]
}
