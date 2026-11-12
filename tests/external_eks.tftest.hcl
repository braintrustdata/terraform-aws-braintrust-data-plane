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
    condition     = length(module.gateway_ecs) == 0 && length(module.gateway_alb) == 0
    error_message = "External EKS must leave gateway resources to Helm by default."
  }

  assert {
    condition     = !local.create_ai_gateway
    error_message = "External EKS must not enable Terraform gateway routes by default."
  }

  assert {
    condition     = length(module.services) == 0
    error_message = "external EKS mode should skip the services module"
  }

  assert {
    condition     = length(module.api_ecs) == 0 && !local.create_ecs_api
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
  assert {
    condition     = length(module.brainstore_deployment) == 0
    error_message = "External EKS must not create an EC2 rollout controller."
  }
}

run "external_eks_ignores_gateway_flags" {
  command = plan

  variables {
    use_global_ai_gateway_origin = false
    ai_gateway_min_capacity      = 0
  }

  assert {
    condition     = length(module.gateway_ecs) == 0 && length(module.gateway_alb) == 0 && length(local.gateway_env_vars) == 0
    error_message = "External EKS must ignore gateway flags and leave the gateway to Helm."
  }

  assert {
    condition     = length(module.api_ecs) == 0 && !local.create_ecs_api
    error_message = "External EKS must create no API ECS."
  }
}

run "standard_gateway_defaults" {
  command = plan

  variables {
    use_deployment_mode_external_eks = false
  }

  assert {
    condition     = length(module.gateway_ecs) == 1 && local.create_ai_gateway && local.create_ecs_api
    error_message = "Standard deployments must create API ECS and the private gateway."
  }
}
