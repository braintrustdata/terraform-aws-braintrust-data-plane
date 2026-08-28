# Plan-mode smoke tests for use_deployment_mode_external_eks.
#
# Primary signal: plan succeeds with services/api_ecs/ingress/brainstore skipped.

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
  deployment_name                  = "bt-test"
  brainstore_license_key           = "test-license"
  use_deployment_mode_external_eks = true
  enable_quarantine_vpc            = true
}

run "external_eks_plans" {
  command = plan

  assert {
    condition     = length(module.services) == 0
    error_message = "external EKS mode should skip the services module"
  }

  assert {
    condition     = length(module.api_ecs) == 0
    error_message = "external EKS mode should skip the api_ecs module"
  }

  assert {
    condition     = length(module.ingress) == 0
    error_message = "external EKS mode should skip the ingress module"
  }

  assert {
    condition     = length(module.brainstore) == 0
    error_message = "external EKS mode should skip the brainstore module"
  }
}

run "external_eks_loop_runtime_plans" {
  command = plan

  variables {
    enable_loop_runtime                  = true
    enable_eks_pod_identity              = true
    loop_runtime_eks_service_account_name = "custom-loop-runtime"
  }

  assert {
    condition     = length(module.loop_runtime_sandbox_aws_microvm) == 1
    error_message = "external EKS Loop Runtime should create the AWS sandbox substrate"
  }

  assert {
    condition     = length(module.loop_runtime_eks) == 1
    error_message = "external EKS Loop Runtime should create its dedicated IAM role"
  }

  assert {
    condition     = length(module.loop_runtime_ecs) == 0
    error_message = "external EKS Loop Runtime should not create the ECS service"
  }

  assert {
    condition     = length(module.loop_runtime_alb) == 0
    error_message = "external EKS Loop Runtime should not create the ECS ALB"
  }

  assert {
    condition     = length(module.ecs) == 0
    error_message = "external EKS Loop Runtime should not create an otherwise-unused ECS cluster"
  }

  assert {
    condition     = module.loop_runtime_eks[0].helm_brainstore_locks_s3_path == "brainstore/locks"
    error_message = "external EKS Loop Runtime should use the Helm Brainstore lock prefix"
  }

  assert {
    condition     = jsondecode(module.loop_runtime_eks[0].assume_role_policy_json).Statement[0].Condition.StringEquals["aws:RequestTag/kubernetes-service-account"][0] == "custom-loop-runtime"
    error_message = "external EKS Loop Runtime Pod Identity trust should be scoped to the configured ServiceAccount"
  }
}
