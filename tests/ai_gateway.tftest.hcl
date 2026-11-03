# Plan-mode smoke test for the required AI gateway. Standard deployments use
# the private gateway unless use_global_ai_gateway_origin selects the hosted one.

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
}

run "ai_gateway_plans" {
  command = plan

  assert {
    condition     = length(module.gateway_ecs) == 1
    error_message = "The default should create the private gateway_ecs module"
  }

  assert {
    condition     = length(module.ecs) == 1
    error_message = "The default should create the shared ECS cluster"
  }

  assert {
    condition     = contains(keys(local.gateway_env_vars), "GATEWAY_URL")
    error_message = "API services must receive GATEWAY_URL for the private gateway"
  }

  assert {
    condition     = length(module.api_ecs) == 1
    error_message = "standard deployments should still create api_ecs alongside the gateway"
  }
}

run "create_and_enable_with_lambda_api" {
  command = plan
  variables {
    enable_ecs_api = false
  }
}

run "create_and_enable_with_ecs_api" {
  command = plan
  variables {
    enable_ecs_api = true
  }
}

run "create_and_enable_all_private_paths" {
  command = plan
  variables {
    enable_ecs_api                       = true
    enable_loop_runtime                  = true
    use_private_gateway_quarantine_proxy = true
  }
}

run "create_and_enable_in_existing_vpc" {
  command = plan
  variables {
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
    braintrust_api_alb_certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/test"
    braintrust_api_alb_custom_domain   = "api.internal.example.com"
  }
}

run "external_eks_leaves_gateway_to_helm" {
  command = plan
  variables {
    use_deployment_mode_external_eks = true
    braintrust_api_url               = "https://api.example.com"
  }

  assert {
    condition     = length(module.gateway_ecs) == 0 && !local.create_ai_gateway
    error_message = "External EKS must leave the gateway to Helm even with an explicit API URL."
  }
}

run "reject_gateway_without_tasks" {
  command = plan
  variables {
    ai_gateway_min_capacity = 0
  }
  expect_failures = [var.ai_gateway_min_capacity]
}

run "hosted_gateway_keeps_alb_and_wires_hosted_url" {
  command = plan
  variables {
    ai_gateway_min_capacity              = 0
    use_global_ai_gateway_origin         = true
    use_private_gateway_quarantine_proxy = true
  }

  assert {
    condition     = length(module.gateway_ecs) == 0 && !local.create_quarantine_gateway_privatelink
    error_message = "The hosted gateway must stop the private gateway service and leave quarantine PrivateLink disabled."
  }

  assert {
    condition     = length(module.gateway_alb) == 1 && local.create_ai_gateway_alb
    error_message = "The gateway ALB and its CloudFront VPC origin must outlive the gateway choice so switching never deletes an attached origin."
  }

  assert {
    condition     = local.gateway_env_vars["GATEWAY_URL"] == "https://gateway.braintrust.dev"
    error_message = "API services must use the hosted gateway base URL."
  }

  assert {
    condition     = local.loop_runtime_ai_proxy_url == "https://gateway.braintrust.dev/v1/proxy"
    error_message = "Loop must use the hosted gateway."
  }
}

run "quarantine_override_keeps_explicit_url" {
  command = plan
  variables {
    use_private_gateway_quarantine_proxy = true
    quarantine_proxy_url                 = "https://proxy.example.com/v1/proxy"
  }

  assert {
    condition     = output.quarantine_proxy_url == "https://proxy.example.com/v1/proxy"
    error_message = "An explicit quarantine_proxy_url must win over PrivateLink."
  }
}

