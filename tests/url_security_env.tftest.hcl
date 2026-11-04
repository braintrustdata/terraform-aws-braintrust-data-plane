# URL-security settings must reach both Lambdas that fetch user-supplied URLs.
# AIProxy previously never received them, so it stayed on the application
# default of warn even when unsafe_url_request_mode was reject.

mock_provider "aws" {
  source = "./tests/mocks/aws"
}

mock_provider "random" {}
mock_provider "http" {
  source = "./tests/mocks/http"
}

variables {
  # Root module inputs.
  primary_org_name            = "test-org"
  brainstore_license_key      = "test-license"
  lambda_version_tag_override = "test-version"

  # modules/services inputs.
  braintrust_org_name         = "test-org"
  deployment_name             = "bt-test"
  vpc_id                      = "vpc-12345678"
  service_subnet_ids          = ["subnet-1", "subnet-2", "subnet-3"]
  postgres_username           = "postgres"
  postgres_password           = "password"
  postgres_host               = "db.example.internal"
  use_redis_replication_group = false
  redis_host                  = "redis.example.internal"
  redis_port                  = "6379"
  whitelisted_origins         = []
  code_bundle_bucket_arn      = "arn:aws:s3:::bt-test-code-bundles"
  lambda_responses_bucket_arn = "arn:aws:s3:::bt-test-lambda-responses"
  api_security_group_id       = "sg-api"
  api_handler_role_arn        = "arn:aws:iam::123456789012:role/bt-test-APIHandlerRole"
  function_tools_secret_key   = "function-tools-secret"
  enable_ecs_api              = false
  use_quarantine_vpc          = false
}

run "set_values_reach_both_lambdas" {
  command = plan
  module { source = "./modules/services" }

  variables {
    unsafe_url_request_mode  = " reject "
    url_security_dns_servers = "1.1.1.1"
    url_security_allow_cidrs = "10.1.2.3/32"
  }

  assert {
    condition = (
      aws_lambda_function.api_handler[0].environment[0].variables["BRAINTRUST_UNSAFE_URL_REQUEST_MODE"] == "reject" &&
      aws_lambda_function.api_handler[0].environment[0].variables["BRAINTRUST_URL_SECURITY_DNS_SERVERS"] == "1.1.1.1" &&
      aws_lambda_function.api_handler[0].environment[0].variables["BRAINTRUST_URL_SECURITY_ALLOW_CIDRS"] == "10.1.2.3/32"
    )
    error_message = "APIHandler should receive the URL-security settings"
  }

  assert {
    condition = (
      aws_lambda_function.ai_proxy[0].environment[0].variables["BRAINTRUST_UNSAFE_URL_REQUEST_MODE"] == "reject" &&
      aws_lambda_function.ai_proxy[0].environment[0].variables["BRAINTRUST_URL_SECURITY_DNS_SERVERS"] == "1.1.1.1" &&
      aws_lambda_function.ai_proxy[0].environment[0].variables["BRAINTRUST_URL_SECURITY_ALLOW_CIDRS"] == "10.1.2.3/32"
    )
    error_message = "AIProxy should receive the same URL-security settings as APIHandler"
  }
}

run "unset_values_leave_env_unchanged" {
  command = plan
  module { source = "./modules/services" }

  assert {
    condition = alltrue([
      for k in ["BRAINTRUST_UNSAFE_URL_REQUEST_MODE", "BRAINTRUST_URL_SECURITY_DNS_SERVERS", "BRAINTRUST_URL_SECURITY_ALLOW_CIDRS"] :
      !contains(keys(aws_lambda_function.ai_proxy[0].environment[0].variables), k) &&
      !contains(keys(aws_lambda_function.api_handler[0].environment[0].variables), k)
    ])
    error_message = "Unset URL-security inputs must not add env vars, so existing Lambdas see no change"
  }
}
