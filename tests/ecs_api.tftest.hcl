# Plan-mode smoke test for the API ECS data plane.
#
# There is no APIHandler, AIProxy, or API Gateway. Quarantine and the other
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
  quarantine_proxy_url   = "https://proxy.example.com/v1/proxy"
}

run "ecs_api_plans" {
  command = plan

  assert {
    condition     = length(module.api_ecs) == 1
    error_message = "The data plane should keep the api_ecs module"
  }

  assert {
    condition     = length(module.services) == 1
    error_message = "The data plane should keep the services module for the remaining Lambdas"
  }

  assert {
    condition     = length(module.ingress) == 1
    error_message = "The data plane should keep ingress for CloudFront routing"
  }

  assert {
    condition     = contains(keys(module.services[0].monitoring_functions), "billing-cron") && contains(keys(module.services[0].monitoring_functions), "automation-cron") && contains(keys(module.services[0].monitoring_functions), "catchup-etl") && !contains(keys(module.services[0].monitoring_functions), "api-handler") && !contains(keys(module.services[0].monitoring_functions), "ai-proxy")
    error_message = "Monitoring should list the cron and CatchupETL Lambdas and no APIHandler or AIProxy"
  }

  assert {
    condition     = output.quarantine_proxy_url == "https://proxy.example.com/v1/proxy"
    error_message = "The data plane should keep the explicit quarantine proxy URL"
  }
}

run "rejects_whitespace_quarantine_proxy_url" {
  command = plan

  variables {
    quarantine_proxy_url = "   "
  }

  expect_failures = [
    var.quarantine_proxy_url,
  ]
}

# No quarantine_proxy_url: quarantine must select the CloudFront hostname
# plus /v1/proxy.
#
# Terraform 1.10 leaves overridden computed attributes unknown during plan,
# so this run overrides the ingress output instead of the distribution.
run "defaults_quarantine_to_cloudfront" {
  command = plan

  override_module {
    target = module.ingress[0]
    outputs = {
      api_url = "https://d111111abcdef8.cloudfront.net"
    }
  }

  variables {
    quarantine_proxy_url = null
  }

  assert {
    condition     = output.quarantine_proxy_url == "https://d111111abcdef8.cloudfront.net/v1/proxy"
    error_message = "The data plane should default quarantine to the CloudFront /v1/proxy URL"
  }
}
