mock_provider "aws" {
  source = "./tests/mocks/aws"
  mock_data "aws_subnet" {
    defaults = { vpc_id = "vpc-0123456789abcdef0" }
  }
  mock_data "aws_partition" {
    defaults = {
      partition = "aws"
    }
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
  enable_ai_gateway      = true
}

run "loop_private_endpoint" {
  command = plan

  override_module {
    target = module.gateway_alb[0]
    outputs = {
      gateway_url                   = "http://private-gateway.example"
      gateway_alb_security_group_id = "sg-1234567890abcdef0"
    }
  }

  assert {
    condition     = length(module.loop_runtime_ecs) == 1 && length(module.loop_runtime_sandbox_aws_microvm) == 1
    error_message = "Loop must create the runtime and MicroVM modules."
  }
  assert {
    condition     = var.loop_runtime_sandbox_egress_mode == "restricted"
    error_message = "MicroVM egress must default to restricted."
  }
  assert {
    condition     = local.loop_runtime_ai_proxy_url == "http://private-gateway.example/v1/proxy"
    error_message = "Loop must send model requests directly to the private gateway."
  }
}

run "loop_requires_gateway" {
  command = plan
  variables {
    create_ai_gateway = false
    enable_ai_gateway = false
  }
  expect_failures = [var.enable_loop_runtime]
}

run "loop_with_existing_vpc" {
  command = plan
  variables {
    create_vpc                   = false
    existing_vpc_id              = "vpc-1234567890abcdef0"
    existing_private_subnet_1_id = "subnet-11111111111111111"
    existing_private_subnet_2_id = "subnet-22222222222222222"
    existing_private_subnet_3_id = "subnet-33333333333333333"
    existing_public_subnet_1_id  = "subnet-44444444444444444"
  }
}

run "loop_requires_enabled_gateway" {
  command = plan
  variables {
    enable_ai_gateway = false
  }
  expect_failures = [var.enable_loop_runtime]
}

run "loop_with_existing_sandbox_vpc" {
  command = plan
  variables {
    loop_runtime_sandbox_existing_vpc_id     = "vpc-0123456789abcdef0"
    loop_runtime_sandbox_existing_subnet_ids = ["subnet-0123456789abcdef0", "subnet-0123456789abcdef1"]
  }
}
