# Plan-mode smoke test for ECS mode (enable_ecs_api = true).
#
# APIHandler, AIProxy, and API Gateway are removed. Quarantine and the other
# Lambdas stay. ECS and CloudFront remain.

mock_provider "aws" {
  source = "./tests/mocks/aws"
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
  enable_ecs_api         = true
  quarantine_proxy_url   = "https://proxy.example.com/v1/proxy"
}

run "ecs_api_cutover_plans" {
  command = plan

  assert {
    condition     = length(module.api_ecs) == 1
    error_message = "ECS mode should keep the api_ecs module"
  }

  assert {
    condition     = length(module.services) == 1
    error_message = "ECS mode should keep the services module for the remaining Lambdas"
  }

  assert {
    condition     = length(module.ingress) == 1
    error_message = "ECS mode should keep ingress for CloudFront routing"
  }

  assert {
    condition     = module.services[0].api_handler_arn == null
    error_message = "ECS mode should not create APIHandler"
  }

  assert {
    condition     = module.services[0].ai_proxy_arn == null && module.services[0].ai_proxy_url == null
    error_message = "ECS mode should not create AIProxy or its public Function URL"
  }

  assert {
    condition     = contains(keys(module.services[0].monitoring_functions), "billing-cron") && contains(keys(module.services[0].monitoring_functions), "automation-cron") && contains(keys(module.services[0].monitoring_functions), "catchup-etl") && !contains(keys(module.services[0].monitoring_functions), "api-handler") && !contains(keys(module.services[0].monitoring_functions), "ai-proxy")
    error_message = "ECS mode should keep cron and CatchupETL Lambdas and drop APIHandler and AIProxy from monitoring"
  }

  assert {
    condition     = module.ingress[0].api_gateway_name == null
    error_message = "ECS mode should not create API Gateway"
  }

  assert {
    condition     = output.quarantine_proxy_url == "https://proxy.example.com/v1/proxy"
    error_message = "ECS mode should keep the explicit quarantine proxy URL"
  }
}

run "rejects_whitespace_quarantine_proxy_url_in_ecs_mode" {
  command = plan

  variables {
    quarantine_proxy_url = "   "
  }

  expect_failures = [
    var.quarantine_proxy_url,
  ]
}

run "rejects_ecs_quarantine_without_proxy_url" {
  command = plan

  variables {
    quarantine_proxy_url = null
  }

  expect_failures = [
    terraform_data.ecs_quarantine_proxy_requirements,
  ]
}
