# The quarantine pruner is opt-in. When enabled it deletes unreferenced
# versions of quarantine functions, so its role must be limited to resources
# tagged BraintrustQuarantine=true, and deletion to qualified (versioned) ARNs.

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
  braintrust_org_name            = "test-org"
  deployment_name                = "bt-test"
  vpc_id                         = "vpc-12345678"
  service_subnet_ids             = ["subnet-1", "subnet-2", "subnet-3"]
  postgres_username              = "postgres"
  postgres_password              = "password"
  postgres_host                  = "db.example.internal"
  use_redis_replication_group    = false
  redis_host                     = "redis.example.internal"
  redis_port                     = "6379"
  whitelisted_origins            = []
  code_bundle_bucket_arn         = "arn:aws:s3:::bt-test-code-bundles"
  lambda_responses_bucket_arn    = "arn:aws:s3:::bt-test-lambda-responses"
  api_security_group_id          = "sg-api"
  api_handler_role_arn           = "arn:aws:iam::123456789012:role/bt-test-APIHandlerRole"
  function_tools_secret_key      = "function-tools-secret"
  use_quarantine_vpc             = true
  quarantine_vpc_id              = "vpc-quarantine"
  quarantine_vpc_private_subnets = ["subnet-q1", "subnet-q2", "subnet-q3"]
}

run "disabled_by_default" {
  command = plan
  module { source = "./modules/services" }

  assert {
    condition = (
      length(aws_lambda_function.quarantine_pruner) == 0 &&
      length(aws_iam_role.quarantine_pruner_role) == 0 &&
      length(aws_iam_role_policy.quarantine_pruner_delete_versions) == 0 &&
      length(aws_iam_role_policy_attachment.quarantine_pruner_vpc_access) == 0 &&
      length(aws_cloudwatch_event_rule.quarantine_pruner_schedule) == 0 &&
      length(aws_cloudwatch_event_target.quarantine_pruner_target) == 0 &&
      length(aws_lambda_permission.allow_quarantine_pruner_eventbridge) == 0
    )
    error_message = "the pruner should create nothing unless enable_quarantine_pruner is set"
  }

  assert {
    condition     = !contains(keys(data.http.lambda_versions), "QuarantinePrunerFunction")
    error_message = "a disabled pruner must not look up its artifact, so tags without it still plan"
  }

  assert {
    condition     = !contains(keys(output.monitoring_functions), "quarantine-pruner")
    error_message = "a disabled pruner must not appear in monitoring_functions"
  }
}

run "enabled_defaults_to_off" {
  command = plan
  module { source = "./modules/services" }

  variables {
    enable_quarantine_pruner = true
  }

  assert {
    condition     = contains(keys(data.http.lambda_versions), "QuarantinePrunerFunction")
    error_message = "an enabled pruner should look up its artifact"
  }

  assert {
    condition     = aws_lambda_function.quarantine_pruner[0].function_name == "bt-test-QuarantinePrunerFunction"
    error_message = "the pruner should use the CloudFormation function name with the deployment prefix"
  }

  assert {
    condition     = aws_lambda_function.quarantine_pruner[0].environment[0].variables["QUARANTINE_PRUNER_MODE"] == "off"
    error_message = "an enabled pruner should default to off"
  }

  assert {
    condition     = aws_cloudwatch_event_rule.quarantine_pruner_schedule[0].state == "ENABLED"
    error_message = "the schedule should stay enabled in off mode; the handler returns early"
  }

  assert {
    condition     = aws_lambda_function.quarantine_pruner[0].environment[0].variables["QUARANTINE_PUB_PRIVATE_VPC_ID"] == "vpc-quarantine"
    error_message = "the pruner should only consider functions in the quarantine VPC"
  }

  assert {
    condition = (
      aws_lambda_function.quarantine_pruner[0].runtime == "nodejs22.x" &&
      aws_lambda_function.quarantine_pruner[0].memory_size == 1024 &&
      aws_lambda_function.quarantine_pruner[0].timeout == 900 &&
      aws_lambda_function.quarantine_pruner[0].architectures == tolist(["arm64"])
    )
    error_message = "the pruner should match the agreed runtime, memory, timeout and architecture"
  }

  assert {
    condition     = length(aws_lambda_function.quarantine_pruner[0].layers) == 0
    error_message = "without observability the pruner should have no layers (it does not use DuckDB)"
  }

  assert {
    condition = (
      toset(aws_lambda_function.quarantine_pruner[0].vpc_config[0].subnet_ids) == toset(["subnet-1", "subnet-2", "subnet-3"]) &&
      toset(aws_lambda_function.quarantine_pruner[0].vpc_config[0].security_group_ids) == toset(["sg-api"])
    )
    error_message = "the pruner should run in the service subnets with the API security group to reach Postgres and Redis"
  }

  assert {
    condition     = aws_cloudwatch_event_rule.quarantine_pruner_schedule[0].schedule_expression == "rate(1 hour)"
    error_message = "the pruner should run hourly"
  }

  assert {
    condition = (
      output.monitoring_functions["quarantine-pruner"].function_name == "bt-test-QuarantinePrunerFunction" &&
      output.monitoring_functions["quarantine-pruner"].timeout_seconds == 900
    )
    error_message = "an enabled pruner should be visible to monitoring integrations"
  }

  assert {
    condition     = aws_iam_role_policy_attachment.quarantine_pruner_vpc_access[0].policy_arn == "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
    error_message = "the pruner role should have VPC access for its ENIs"
  }
}

run "observability_adds_datadog_layers_only" {
  command = plan
  module { source = "./modules/services" }

  variables {
    enable_quarantine_pruner       = true
    internal_observability_api_key = "test-dd-key"
  }

  assert {
    condition = (
      length(aws_lambda_function.quarantine_pruner[0].layers) == 2 &&
      alltrue([for layer in aws_lambda_function.quarantine_pruner[0].layers : strcontains(layer, ":layer:Datadog-")])
    )
    error_message = "with observability the pruner should get the Datadog Node and extension layers, and no DuckDB layer"
  }

  assert {
    condition = (
      aws_lambda_function.quarantine_pruner[0].environment[0].variables["DD_SERVICE"] == "QuarantinePrunerFunction" &&
      aws_lambda_function.quarantine_pruner[0].environment[0].variables["DD_LAMBDA_HANDLER"] == "index.handler"
    )
    error_message = "the Datadog wrapper should know the pruner service name and original handler"
  }
}

run "role_is_tag_conditioned" {
  command = plan
  module { source = "./modules/services" }

  variables {
    enable_quarantine_pruner = true
    permissions_boundary_arn = "arn:aws:iam::123456789012:policy/boundary"
  }

  assert {
    condition     = aws_iam_role.quarantine_pruner_role[0].permissions_boundary == "arn:aws:iam::123456789012:policy/boundary"
    error_message = "the pruner role should respect the permissions boundary"
  }

  assert {
    condition = (
      length(jsondecode(aws_iam_role_policy.quarantine_pruner_delete_versions[0].policy).Statement) == 2 &&
      alltrue([
        for statement in jsondecode(aws_iam_role_policy.quarantine_pruner_delete_versions[0].policy).Statement :
        statement.Effect == "Allow" && statement.Condition.StringEquals["aws:ResourceTag/BraintrustQuarantine"] == "true"
      ])
    )
    error_message = "every pruner statement must be conditioned on BraintrustQuarantine=true"
  }

  assert {
    condition = (
      toset(jsondecode(aws_iam_role_policy.quarantine_pruner_delete_versions[0].policy).Statement[0].Action) == toset([
        "lambda:ListVersionsByFunction",
        "lambda:ListAliases",
      ]) &&
      jsondecode(aws_iam_role_policy.quarantine_pruner_delete_versions[0].policy).Statement[0].Resource == "*"
    )
    error_message = "listing may use any resource, so unqualified ARNs work"
  }

  assert {
    condition = (
      jsondecode(aws_iam_role_policy.quarantine_pruner_delete_versions[0].policy).Statement[1].Action == ["lambda:DeleteFunction"] &&
      jsondecode(aws_iam_role_policy.quarantine_pruner_delete_versions[0].policy).Statement[1].Resource == "arn:aws:lambda:us-east-1:123456789012:function:*:*"
    )
    error_message = "deletion must require a qualified ARN in this region and account so a whole function cannot be deleted"
  }
}

run "dry_run_mode_is_passed_through" {
  command = plan
  module { source = "./modules/services" }

  variables {
    enable_quarantine_pruner = true
    quarantine_pruner_mode   = "dry-run"
  }

  assert {
    condition     = aws_lambda_function.quarantine_pruner[0].environment[0].variables["QUARANTINE_PRUNER_MODE"] == "dry-run"
    error_message = "dry-run should be passed to the function"
  }
}

run "extra_env_vars_override_defaults" {
  command = plan
  module { source = "./modules/services" }

  variables {
    enable_quarantine_pruner = true
    extra_env_vars = {
      APIHandler               = {}
      AIProxy                  = {}
      BillingCron              = {}
      CatchupETL               = {}
      MigrateDatabaseFunction  = {}
      QuarantineWarmupFunction = {}
      AutomationCron           = {}
      QuarantinePrunerFunction = { QUARANTINE_PRUNER_MODE = "on" }
    }
  }

  assert {
    condition     = aws_lambda_function.quarantine_pruner[0].environment[0].variables["QUARANTINE_PRUNER_MODE"] == "on"
    error_message = "QuarantinePrunerFunction extra env vars should be merged last"
  }
}

run "extra_env_vars_without_pruner_key" {
  command = plan
  module { source = "./modules/services" }

  variables {
    enable_quarantine_pruner = true
    extra_env_vars = {
      APIHandler               = {}
      AIProxy                  = {}
      BillingCron              = {}
      CatchupETL               = {}
      MigrateDatabaseFunction  = {}
      QuarantineWarmupFunction = {}
      AutomationCron           = {}
    }
  }

  assert {
    condition     = aws_lambda_function.quarantine_pruner[0].environment[0].variables["QUARANTINE_PRUNER_MODE"] == "off"
    error_message = "callers that list only the existing services should still plan"
  }
}

run "rejects_invalid_mode" {
  command = plan
  module { source = "./modules/services" }

  variables {
    enable_quarantine_pruner = true
    quarantine_pruner_mode   = "delete"
  }

  expect_failures = [
    var.quarantine_pruner_mode,
  ]
}

run "root_rejects_pruner_without_quarantine_vpc" {
  command = plan

  variables {
    enable_quarantine_vpc    = false
    enable_quarantine_pruner = true
  }

  expect_failures = [
    var.enable_quarantine_pruner,
  ]
}

run "root_service_extra_env_vars_without_pruner_key" {
  command = plan

  variables {
    enable_quarantine_pruner = true
    service_extra_env_vars = {
      APIHandler               = {}
      AIProxy                  = {}
      CatchupETL               = {}
      BillingCron              = {}
      MigrateDatabaseFunction  = {}
      QuarantineWarmupFunction = {}
      AutomationCron           = {}
    }
  }

  assert {
    condition     = length(module.services) == 1
    error_message = "existing callers that list only the existing services should still plan"
  }
}
