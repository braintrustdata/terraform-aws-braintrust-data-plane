# Plan-mode smoke test for ECS mode (enable_ecs_api = true).
#
# APIHandler, AIProxy, and API Gateway are removed. Quarantine and the other
# Lambdas stay. ECS and CloudFront remain.

mock_provider "aws" {
  source = "./tests/mocks/aws"

  # Plan leaves aws_cloudfront_distribution.domain_name unknown unless a mock
  # value is supplied. The quarantine fallback test asserts that URL.
  override_resource {
    target = module.ingress[0].aws_cloudfront_distribution.dataplane
    values = {
      domain_name = "d111111abcdef8.cloudfront.net"
    }
    override_during = plan
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

# No quarantine_proxy_url: ECS mode must select the mocked CloudFront
# hostname plus /v1/proxy. A null fallback would also leave AIProxy absent,
# so the URL assertion is what proves the fallback.
run "ecs_mode_defaults_quarantine_to_cloudfront" {
  command = plan

  variables {
    quarantine_proxy_url = null
  }

  assert {
    condition     = module.services[0].ai_proxy_url == null
    error_message = "ECS mode should still remove the AI Proxy Function URL when the quarantine URL is left unset"
  }

  assert {
    condition     = output.quarantine_proxy_url == "https://d111111abcdef8.cloudfront.net/v1/proxy"
    error_message = "ECS mode should default quarantine to the CloudFront /v1/proxy URL"
  }
}
