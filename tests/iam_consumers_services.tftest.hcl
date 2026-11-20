# The services module takes its Lambda execution roles as inputs. These runs check
# that each function runs as the role it was given, and that Lambda mode refuses
# to start without the AIProxy invoke role. See iam_consumers.tftest.hcl for the
# modules that run on ECS and EC2.

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
  lambda_version_tag_override = "test-version"
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
  function_tools_secret_key   = "function-tools-secret"

  # Lambda mode with quarantine and the pruner keeps every function.
  enable_ecs_api                 = false
  use_quarantine_vpc             = true
  quarantine_vpc_id              = "vpc-quarantine"
  quarantine_vpc_private_subnets = ["subnet-q1", "subnet-q2", "subnet-q3"]
  enable_quarantine_pruner       = true

  api_handler_role_arn                = "arn:aws:iam::123456789012:role/bt-test-APIHandlerRole"
  automation_cron_role_arn            = "arn:aws:iam::123456789012:role/bt-test-AutomationCronRole"
  billing_cron_role_arn               = "arn:aws:iam::123456789012:role/bt-test-BillingCronRole"
  catchup_etl_role_arn                = "arn:aws:iam::123456789012:role/bt-test-CatchupETLRole"
  automation_cron_schedule_role_arn   = "arn:aws:iam::123456789012:role/bt-test-AutomationCronScheduleRole"
  billing_cron_schedule_role_arn      = "arn:aws:iam::123456789012:role/bt-test-BillingCronScheduleRole"
  catchup_etl_schedule_role_arn       = "arn:aws:iam::123456789012:role/bt-test-CatchupETLScheduleRole"
  quarantine_pruner_schedule_role_arn = "arn:aws:iam::123456789012:role/bt-test-QuarantinePrunerScheduleRole"
  migrate_database_role_arn           = "arn:aws:iam::123456789012:role/bt-test-MigrateDatabaseFunctionRole"
  quarantine_pruner_role_arn          = "arn:aws:iam::123456789012:role/bt-test-QuarantinePrunerRole"
  quarantine_warmup_role_arn          = "arn:aws:iam::123456789012:role/bt-test-QuarantineWarmupRole"
  ai_proxy_invoke_role_arn            = "arn:aws:iam::123456789012:role/bt-test-AIProxyInvokeRole"
}

run "lambda_functions_run_as_the_supplied_roles" {
  command = plan
  module { source = "./modules/services" }

  assert {
    condition = (
      aws_lambda_function.automation_cron.role == var.automation_cron_role_arn
      && aws_lambda_function.billing_cron.role == var.billing_cron_role_arn
      && aws_lambda_function.catchup_etl.role == var.catchup_etl_role_arn
      && aws_lambda_function.migrate_database.role == var.migrate_database_role_arn
      && aws_lambda_function.quarantine_pruner[0].role == var.quarantine_pruner_role_arn
      && aws_lambda_function.quarantine_warmup[0].role == var.quarantine_warmup_role_arn
    )
    error_message = "Each Lambda function must run as the role it was given, so none falls back to a shared role."
  }

  assert {
    condition     = aws_lambda_function.api_handler[0].role == var.api_handler_role_arn && aws_lambda_function.ai_proxy[0].role == var.api_handler_role_arn
    error_message = "The APIHandler and AIProxy Lambdas must run as the shared API role."
  }

  assert {
    condition     = aws_lambda_function.api_handler[0].environment[0].variables["AI_PROXY_INVOKE_ROLE"] == var.ai_proxy_invoke_role_arn
    error_message = "The APIHandler Lambda must assume the supplied AIProxy invoke role."
  }
}

run "rejects_the_apihandler_lambda_without_the_ai_proxy_invoke_role" {
  command = plan
  module { source = "./modules/services" }

  variables {
    ai_proxy_invoke_role_arn = null
  }

  expect_failures = [aws_lambda_function.api_handler[0]]
}

run "ecs_mode_needs_no_ai_proxy_invoke_role" {
  command = plan
  module { source = "./modules/services" }

  variables {
    enable_ecs_api           = true
    ai_proxy_invoke_role_arn = null
  }

  assert {
    condition     = length(aws_lambda_function.api_handler) == 0
    error_message = "With enable_ecs_api, the APIHandler Lambda must not exist, so it needs no invoke role."
  }
}
