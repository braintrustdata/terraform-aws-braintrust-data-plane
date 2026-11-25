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

override_data {
  target = module.sandbox_service[0].data.http.release
  values = {
    status_code   = 200
    response_body = <<-YAML
      # Public release metadata subset used by the Sandbox Service lookup tests.
      # Artifact source: https://braintrust-cf-us-east-1.s3.amazonaws.com/braintrust-v2.24.0.yaml
      # Required installer capabilities are mocked independently of these pins.
      Outputs:
        SandboxServiceBootstrapCapabilities:
          Value: license-secret,nodegroup-cleanup
        SandboxServiceChartUrl:
          Value: https://braintrust-cf-us-east-1.s3.amazonaws.com/sandbox-service/062fbf5e1090e1f624eda6d6f9dfe7af05921e3d90a6405d330feb7866775ad2/sandbox-service-0.1.0.tgz
        SandboxServiceHelmValues:
          Value:
            Fn::Sub:
              - |
                {
                  "hostname": "nodes.$${AWS::StackName}.sandbox.internal",
                  "image": "public.ecr.aws/braintrust/sandbox-service:053f8aef2ad66bb17ef868e35e0c3f9263e05c93",
                  "prewarmTemplates": [{
                    "image": "public.ecr.aws/braintrust/codex-runtime@sha256:6d7c649f35f335377d48fadd9b251e4ad4987d03427cc9ea730b87024c0811b5",
                    "resources": {
                      "vcpu_count": $${LoopRuntimeSandboxVcpuCount},
                      "memory_mib": $${LoopRuntimeSandboxMemoryMiB}
                    }
                  }]
                }
              - {}
      Resources:
        SandboxServiceReleaseFunction:
          Properties:
            CodeUri: s3://braintrust-cf-us-east-1/e6f89a1994f5cb53a5ee7e0f7c5eea27
        SandboxServiceRelease:
          Properties:
            ProviderVersion: cf3f36db527625591bfc987f7f5fd35e0c8b1e0ce5c6ae17d57ba9e9124c3a19
      YAML
  }
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
      local.loop_runtime_version == jsondecode(file("${path.module}/modules/loop-runtime-ecs/VERSIONS.json"))["loop-runtime"] &&
      output.sandbox_service_client_tls_secret_arn == null
    )
    error_message = "Existing Loop deployments must retain their Lambda backend and runtime release by default."
  }
}

run "service_replaces_lambda_in_managed_vpc" {
  command = plan
  variables {
    s3_vpc_endpoint_resource_org_ids = ["o-1234567890"]
    enable_sandbox_service           = true
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
