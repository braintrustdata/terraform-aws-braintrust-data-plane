# Lambda REDIS_URL scheme: plaintext redis:// for legacy clusters, authenticated
# rediss:// for replication groups.

mock_provider "aws" {
  source = "./tests/mocks/aws"
}

mock_provider "random" {}

mock_provider "http" {
  source = "./tests/mocks/http"
}

variables {
  braintrust_org_name         = "test-org"
  deployment_name             = "bt-test"
  vpc_id                      = "vpc-0123456789abcdef0"
  service_subnet_ids          = ["subnet-0123456789abcdef0", "subnet-0123456789abcdef1"]
  postgres_username           = "braintrust"
  postgres_password           = "password"
  postgres_host               = "db.example.internal"
  postgres_port               = 5432
  redis_host                  = "redis.example.internal"
  redis_port                  = "6379"
  use_quarantine_vpc          = false
  brainstore_enabled          = false
  whitelisted_origins         = ["https://example.com"]
  code_bundle_bucket_arn      = "arn:aws:s3:::bt-test-code"
  lambda_responses_bucket_arn = "arn:aws:s3:::bt-test-responses"
  api_security_group_id       = "sg-0123456789abcdef0"
  api_handler_role_arn        = "arn:aws:iam::123456789012:role/bt-test-api-handler"
  function_tools_secret_key   = "test-function-tools-secret"
  lambda_version_tag_override = "test-version"
}

run "legacy_cluster_uses_redis_scheme" {
  command = plan

  module {
    source = "./modules/services"
  }

  variables {
    use_redis_replication_group = false
    redis_auth_token            = null
  }

  assert {
    condition = (
      aws_lambda_function.automation_cron.environment[0].variables["REDIS_URL"] == "redis://redis.example.internal:6379"
    )
    error_message = "Legacy ElastiCache clusters must render REDIS_URL as redis://host:port."
  }
}

run "replication_group_uses_rediss_scheme" {
  command = plan

  module {
    source = "./modules/services"
  }

  variables {
    use_redis_replication_group = true
    redis_auth_token            = "mock-auth-token"
  }

  assert {
    condition = (
      aws_lambda_function.automation_cron.environment[0].variables["REDIS_URL"] == "rediss://:mock-auth-token@redis.example.internal:6379"
    )
    error_message = "Replication groups must render REDIS_URL as rediss://:token@host:port."
  }
}
