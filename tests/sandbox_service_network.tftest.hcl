mock_provider "helm" {}

mock_provider "aws" {
  source = "./tests/mocks/aws"
  mock_data "aws_iam_session_context" {
    defaults = { issuer_arn = "arn:aws:iam::123456789012:role/terraform-installer" }
  }
  mock_data "aws_secretsmanager_secret_versions" {
    defaults = { versions = [{ version_id = "tls-version-one", version_stages = ["AWSCURRENT"] }] }
  }
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
  braintrust_org_name                   = "test-org"
  primary_org_name                      = "test-org"
  deployment_name                       = "bt-test"
  brainstore_license_key                = "test-license"
  enable_loop_runtime                   = true
  sandbox_service_server_tls_secret_arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:sandbox-server"
  sandbox_service_client_tls_secret_arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:sandbox-client"
}

run "lambda_only_by_default" {
  command = plan
  assert {
    condition = (
      length(module.sandbox_service) == 0 &&
      length(module.loop_runtime_sandbox_aws_microvm) == 1 &&
      length(module.loop_runtime_ecs) == 1 &&
      local.loop_runtime_version == jsondecode(file("${path.module}/modules/loop-runtime-ecs/VERSIONS.json"))["loop-runtime"] &&
      output.sandbox_service_client_tls_secret_arn == null
    )
    error_message = "Existing Loop deployments must retain their Lambda backend and runtime release by default."
  }
}

run "service_replaces_lambda_in_managed_vpc" {
  command = plan
  variables {
    enable_sandbox_service = true
  }
  assert {
    condition = (
      length(module.sandbox_service) == 1 &&
      length(module.loop_runtime_sandbox_aws_microvm) == 0 &&
      length(module.loop_runtime_ecs) == 1 &&
      output.loop_runtime_microvm_image_arn == null
    )
    error_message = "The hard cutover must replace Lambda infrastructure and retain one Loop Runtime service."
  }
}

run "exposes_client_tls_secret_arn" {
  command = plan
  variables {
    enable_sandbox_service = true
  }
  override_module {
    target = module.sandbox_service
    outputs = {
      endpoint                         = "https://nodes.bt-test.sandbox.internal:9400"
      cluster_name                     = "bt-test-sandbox-service"
      client_tls_secret_version        = "tls-version-one"
      client_tls_secret_arn            = "arn:aws:secretsmanager:us-east-1:123456789012:secret:bt-test-sandbox-service-client-tls"
      worker_security_group_id         = "sg-0123456789abcdef0"
      egress_gateway_security_group_id = "sg-0123456789abcdef1"
      egress_gateway_target_group_arn  = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/bt-test-sandbox-eg/2222222222222222"
      egress_gateway_dns_name          = "sandbox-egress.example.internal"
      sandbox_image                    = "public.ecr.aws/braintrust/codex-runtime:test"
      kubernetes_api_url               = "https://eks.example.internal"
      kubernetes_ca                    = "test-ca"
    }
  }
  assert {
    condition     = output.sandbox_service_client_tls_secret_arn == "arn:aws:secretsmanager:us-east-1:123456789012:secret:bt-test-sandbox-service-client-tls"
    error_message = "Root callers must receive the Sandbox Service client TLS secret ARN required by the mTLS endpoint."
  }
}

run "service_in_existing_vpc" {
  command = plan
  variables {
    enable_sandbox_service                       = true
    create_vpc                                   = false
    existing_vpc_id                              = "vpc-0123456789abcdef0"
    existing_private_subnet_1_id                 = "subnet-0123456789abcdef0"
    existing_private_subnet_2_id                 = "subnet-0123456789abcdef1"
    existing_private_subnet_3_id                 = "subnet-0123456789abcdef2"
    existing_public_subnet_1_id                  = "subnet-0123456789abcdef3"
    sandbox_service_existing_private_subnet_1_id = "subnet-worker-one"
    sandbox_service_existing_private_subnet_2_id = "subnet-worker-two"
    sandbox_service_existing_private_subnet_3_id = "subnet-worker-three"
  }
  assert {
    condition = (
      length(module.main_vpc) == 0 &&
      length(module.sandbox_service) == 1 &&
      local.main_vpc_private_subnet_ids == ["subnet-0123456789abcdef0", "subnet-0123456789abcdef1", "subnet-0123456789abcdef2"]
    )
    error_message = "Sandbox Service must use the existing VPC without creating or changing its network."
  }
}

run "rejects_service_without_loop" {
  command = plan
  variables {
    enable_sandbox_service = true
    enable_loop_runtime    = false
  }
  expect_failures = [var.enable_sandbox_service]
}

run "rejects_missing_server_tls" {
  command = plan
  variables {
    enable_sandbox_service                = true
    sandbox_service_server_tls_secret_arn = null
  }
  expect_failures = [var.sandbox_service_server_tls_secret_arn]
}

run "rejects_missing_client_tls" {
  command = plan
  variables {
    enable_sandbox_service                = true
    sandbox_service_client_tls_secret_arn = ""
  }
  expect_failures = [var.sandbox_service_client_tls_secret_arn]
}
