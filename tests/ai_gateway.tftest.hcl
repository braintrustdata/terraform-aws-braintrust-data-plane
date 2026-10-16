# Plan-mode smoke test for private AI gateway infra (create_ai_gateway = true).
#
# Primary signal: plan succeeds for the infra-only first step of the gateway cutover.

mock_provider "aws" {
  source = "./tests/mocks/aws"
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
  enable_quarantine_vpc  = true
  create_ai_gateway      = true
  enable_ai_gateway      = false
}

run "ai_gateway_plans" {
  command = plan

  assert {
    condition     = length(module.gateway_ecs) == 1
    error_message = "create_ai_gateway should create the gateway_ecs module"
  }

  assert {
    condition     = length(module.ecs) == 1
    error_message = "create_ai_gateway should create the shared ECS cluster"
  }

  assert {
    condition     = length(module.api_ecs) == 1
    error_message = "standard deployments should still create api_ecs alongside the gateway"
  }
}

run "create_and_enable_with_lambda_api" {
  command = plan
  variables {
    enable_ai_gateway = true
  }
}

run "create_and_enable_with_ecs_api" {
  command = plan
  variables {
    enable_ai_gateway = true
    enable_ecs_api    = true
  }
}

run "create_and_enable_all_private_paths" {
  command = plan
  variables {
    enable_ai_gateway                    = true
    enable_ecs_api                       = true
    enable_loop_runtime                  = true
    use_private_ai_gateway_origin        = true
    use_private_gateway_quarantine_proxy = true
  }
}

run "create_and_enable_in_existing_vpc" {
  command = plan
  variables {
    enable_ai_gateway            = true
    create_vpc                   = false
    existing_vpc_id              = "vpc-12345678"
    existing_private_subnet_1_id = "subnet-11111111"
    existing_private_subnet_2_id = "subnet-22222222"
    existing_private_subnet_3_id = "subnet-33333333"
    existing_public_subnet_1_id  = "subnet-44444444"
  }
}

run "create_and_enable_with_https_api" {
  command = plan
  variables {
    enable_ai_gateway                  = true
    braintrust_api_alb_certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/test"
    braintrust_api_alb_custom_domain   = "api.internal.example.com"
  }
}

run "external_eks_leaves_gateway_to_helm" {
  command = plan
  variables {
    enable_ai_gateway                = true
    use_deployment_mode_external_eks = true
    braintrust_api_url               = "https://api.example.com"
  }

  assert {
    condition     = length(module.gateway_ecs) == 0 && !local.enable_ai_gateway
    error_message = "External EKS must leave the gateway to Helm even with an explicit API URL."
  }
}

run "disable_gateway_cutover" {
  command = plan
  assert {
    condition     = length(local.gateway_env_vars) == 0
    error_message = "The disabled gateway must not override API environment values."
  }
}

run "reject_gateway_cutover_without_tasks" {
  command = plan
  variables {
    enable_ai_gateway       = true
    ai_gateway_min_capacity = 0
  }
  expect_failures = [var.ai_gateway_min_capacity]
}

run "reject_direct_cloudfront_without_tasks" {
  command = plan
  variables {
    use_private_ai_gateway_origin = true
    ai_gateway_min_capacity       = 0
  }
  expect_failures = [var.ai_gateway_min_capacity]
}

run "reject_privatelink_without_tasks" {
  command = plan
  variables {
    use_private_gateway_quarantine_proxy = true
    ai_gateway_min_capacity              = 0
  }
  expect_failures = [var.ai_gateway_min_capacity]
}

run "allow_zero_tasks_before_cutover" {
  command = plan
  variables {
    ai_gateway_min_capacity = 0
  }
}

run "hosted_gateway_keeps_privatelink_noop" {
  command = plan
  variables {
    ai_gateway_min_capacity              = 0
    use_global_ai_gateway_origin         = true
    use_private_gateway_quarantine_proxy = true
  }
}

run "quarantine_override_does_not_require_gateway_tasks" {
  command = plan
  variables {
    ai_gateway_min_capacity              = 0
    use_private_gateway_quarantine_proxy = true
    quarantine_proxy_url                 = "https://proxy.example.com/v1/proxy"
  }
}
