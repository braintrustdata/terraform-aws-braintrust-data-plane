# Loop requires a Gateway. use_private_ai_gateway_origin does not satisfy the check.

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

run "rejects_loop_runtime_without_gateway" {
  command = plan

  variables {
    enable_ai_gateway             = false
    use_global_ai_gateway_origin  = false
    use_private_ai_gateway_origin = true
  }

  expect_failures = [
    var.enable_loop_runtime,
  ]
}

run "allows_loop_runtime_with_private_gateway" {
  command = plan

  variables {
    enable_ai_gateway            = true
    use_global_ai_gateway_origin = false
  }

  assert {
    condition     = local.enable_ai_gateway && length(module.loop_runtime_ecs) == 1
    error_message = "enable_ai_gateway must satisfy the Loop gateway check and still create the runtime."
  }
}

run "allows_loop_runtime_with_hosted_gateway" {
  command = plan

  variables {
    enable_ai_gateway             = false
    use_global_ai_gateway_origin  = true
    use_private_ai_gateway_origin = false
  }

  assert {
    condition     = local.loop_runtime_ai_proxy_url == "https://gateway.braintrust.dev/v1/proxy" && length(module.loop_runtime_ecs) == 1
    error_message = "use_global_ai_gateway_origin must satisfy the Loop gateway check and point model calls at the hosted gateway."
  }
}
