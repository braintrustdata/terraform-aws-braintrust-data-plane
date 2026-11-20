# The inputs that choose who owns IAM and which identities the module uses:
# iam_owner, create_iam, override_iam_names, existing_iam, region and
# account_id. Most runs plan modules/iam directly, because a root plan can't see
# its variable validations or lookups. The last two plan the root module.
#
# With create_iam = false the module looks roles up. The mock returns a role that
# security created, with the customer owner tag. A run overrides one lookup when
# it needs a different ARN, path or tag. The ownership-tag cases are in
# iam_external_mode.tftest.hcl.

mock_provider "aws" {
  source = "./tests/mocks/aws"
  mock_data "aws_partition" {
    defaults = { partition = "aws" }
  }
  mock_data "aws_iam_role" {
    defaults = {
      arn  = "arn:aws:iam::123456789012:role/mock"
      path = "/"
      tags = { BraintrustIAMOwner = "customer" }
    }
  }
  mock_data "aws_iam_instance_profile" {
    defaults = {
      arn      = "arn:aws:iam::123456789012:instance-profile/mock"
      path     = "/"
      role_arn = "arn:aws:iam::123456789012:role/mock"
    }
  }
}

mock_provider "random" {}

mock_provider "http" {
  source = "./tests/mocks/http"
}

variables {
  deployment_name = "bt-test"
  region          = "us-east-1"
  account_id      = "123456789012"
}

run "plans_standalone_call_without_created_resources" {
  command = plan
  module { source = "./modules/iam" }

  variables {
    iam_owner                  = "customer"
    enable_quarantine_vpc      = true
    enable_quarantine_pruner   = true
    existing_quarantine_vpc_id = "vpc-0123456789abcdef0"
    brainstore_asg_names       = []
  }

  assert {
    condition = (
      length(aws_iam_role.api_handler) == 1
      && length(aws_iam_role.api_ecs_task_execution) == 1
      && length(aws_iam_role.gateway_task_execution) == 1
      && length(aws_iam_role.gateway_task) == 1
      && length(aws_iam_role.brainstore) == 1
      && length(aws_iam_role.brainstore_deployment_waiter) == 1
      && length(aws_iam_role.db_monitoring) == 1
      && length(aws_iam_role.quarantine_invoke) == 1
      && length(aws_iam_role.quarantine_function) == 1
      && length(aws_iam_role.automation_cron) == 1
      && length(aws_iam_role.billing_cron) == 1
      && length(aws_iam_role.catchup_etl) == 1
      && length(aws_iam_role.migrate_database) == 1
      && length(aws_iam_role.quarantine_pruner) == 1
      && length(aws_iam_role.quarantine_warmup) == 1
      && length(aws_iam_role.automation_cron_schedule) == 1
      && length(aws_iam_role.billing_cron_schedule) == 1
      && length(aws_iam_role.catchup_etl_schedule) == 1
      && length(aws_iam_role.quarantine_pruner_schedule) == 1
      && length(aws_iam_instance_profile.brainstore) == 1
    )
    error_message = "A standalone run must plan every role that external mode looks up, without created_resources."
  }
}

run "tags_standalone_resources_with_customer_owner" {
  command = plan
  module { source = "./modules/iam" }

  variables {
    iam_owner                  = "customer"
    enable_quarantine_vpc      = true
    enable_quarantine_pruner   = true
    existing_quarantine_vpc_id = "vpc-0123456789abcdef0"
    custom_tags                = { Environment = "test" }
  }

  assert {
    condition = alltrue([
      for tags in [
        aws_iam_role.db_monitoring[0].tags,
        aws_iam_role.brainstore_deployment_waiter[0].tags,
        aws_iam_role.api_ecs_task_execution[0].tags,
        aws_iam_role.gateway_task_execution[0].tags,
        aws_iam_role.gateway_task[0].tags,
        aws_iam_role.api_handler[0].tags,
        aws_iam_role.brainstore[0].tags,
        aws_iam_role.quarantine_invoke[0].tags,
        aws_iam_role.quarantine_function[0].tags,
        aws_iam_policy.api_handler[0].tags,
        aws_iam_policy.api_handler_quarantine[0].tags,
        aws_iam_policy.api_handler_lambda_policies[0].tags,
        aws_iam_instance_profile.brainstore[0].tags,
        aws_iam_role.automation_cron[0].tags,
        aws_iam_role.billing_cron[0].tags,
        aws_iam_role.catchup_etl[0].tags,
        aws_iam_role.migrate_database[0].tags,
        aws_iam_role.quarantine_pruner[0].tags,
        aws_iam_role.quarantine_warmup[0].tags,
        aws_iam_role.automation_cron_schedule[0].tags,
        aws_iam_role.billing_cron_schedule[0].tags,
        aws_iam_role.catchup_etl_schedule[0].tags,
        aws_iam_role.quarantine_pruner_schedule[0].tags,
      ] : tags.BraintrustIAMOwner == "customer" && tags.Environment == "test"
    ])
    error_message = "Every role, managed policy and instance profile in a standalone run must carry BraintrustIAMOwner = customer, and keep the caller's other tags."
  }
}

run "skips_default_and_ai_proxy_invoke_roles_in_standalone_call" {
  command = plan
  module { source = "./modules/iam" }

  variables {
    iam_owner = "customer"
  }

  # This run uses ECS ingress, where the AIProxy invoke role is absent anyway, so
  # only the default role assertion discriminates. rejects_lambda_ingress_in_standalone_call
  # covers the AIProxy invoke role.
  assert {
    condition = (
      length(aws_iam_role.default) == 0
      && length(aws_iam_role_policy_attachment.default_vpc_access) == 0
      && length(aws_iam_role_policy.default) == 0
      && length(aws_iam_role.ai_proxy_invoke) == 0
      && length(aws_iam_role_policy.ai_proxy_invoke) == 0
      && length(aws_iam_role_policies_exclusive.ai_proxy_invoke) == 0
    )
    error_message = "A standalone run must create neither the default role nor the AIProxy invoke role."
  }
}

run "keeps_default_role_in_the_managed_call" {
  command = plan
  module { source = "./modules/iam" }

  variables {
    created_resources = {
      kms_key_arn                       = "arn:aws:kms:us-east-1:123456789012:key/11111111-1111-1111-1111-111111111111"
      database_secret_arn               = "arn:aws:secretsmanager:us-east-1:123456789012:secret:bt-test/DatabaseSecret-AbCdEf"
      database_url_secret_arn           = "arn:aws:secretsmanager:us-east-1:123456789012:secret:bt-test/DatabaseUrl-AbCdEf"
      function_tools_secret_arn         = "arn:aws:secretsmanager:us-east-1:123456789012:secret:bt-test/FunctionToolsSecret-AbCdEf"
      redis_url_secret_arn              = "arn:aws:secretsmanager:us-east-1:123456789012:secret:bt-test/RedisUrl-AbCdEf"
      brainstore_license_key_secret_arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:bt-test/brainstore/license-key-AbCdEf"
      brainstore_s3_bucket_arn          = "arn:aws:s3:::bt-test-brainstore-1"
      code_bundle_s3_bucket_arn         = "arn:aws:s3:::bt-test-code-bundles-1"
      lambda_responses_s3_bucket_arn    = "arn:aws:s3:::bt-test-lambda-responses-1"
    }
    brainstore_deployment_log_group_arn = "arn:aws:logs:us-east-1:123456789012:log-group:/braintrust/bt-test/bt-test-BrainstoreDeployment"
    brainstore_asg_names                = ["bt-test-brainstore-reader-123"]
  }

  assert {
    condition     = length(aws_iam_role.default) == 1 && length(aws_iam_role_policy.default) == 1 && aws_iam_role.default[0].tags.BraintrustIAMOwner == "braintrust"
    error_message = "The managed call must keep the default role with the braintrust owner tag."
  }
}

run "rejects_unknown_iam_owner" {
  command = plan
  module { source = "./modules/iam" }

  variables {
    iam_owner = "security"
  }

  expect_failures = [var.iam_owner]
}

run "rejects_customer_owner_without_create_iam" {
  command = plan
  module { source = "./modules/iam" }

  variables {
    iam_owner  = "customer"
    create_iam = false
  }

  expect_failures = [var.iam_owner]
}

run "rejects_region_that_differs_from_the_provider" {
  command = plan
  module { source = "./modules/iam" }

  variables {
    iam_owner = "customer"
    region    = "eu-west-1"
  }

  expect_failures = [data.aws_region.current]
}

run "rejects_account_that_differs_from_the_provider" {
  command = plan
  module { source = "./modules/iam" }

  variables {
    iam_owner  = "customer"
    account_id = "999999999999"
  }

  expect_failures = [data.aws_caller_identity.current]
}

run "resolves_default_names_when_both_maps_are_empty" {
  command = plan
  module { source = "./modules/iam" }

  variables {
    create_iam                 = false
    enable_quarantine_vpc      = true
    enable_quarantine_pruner   = true
    brainstore_asg_names       = []
    existing_quarantine_vpc_id = "vpc-0123456789abcdef0"
  }

  assert {
    condition = toset(keys(data.aws_iam_role.external)) == toset([
      "api_handler", "api_ecs_task_execution", "brainstore", "quarantine_invoke", "quarantine_function",
      "gateway_task_execution", "gateway_task", "db_monitoring", "brainstore_deployment_waiter",
      "automation_cron", "billing_cron", "catchup_etl", "migrate_database", "quarantine_pruner", "quarantine_warmup",
      "automation_cron_schedule", "billing_cron_schedule", "catchup_etl_schedule", "quarantine_pruner_schedule",
    ])
    error_message = "External mode must look up every role that the enabled features need, and neither the default nor the AIProxy invoke role."
  }

  assert {
    condition = (
      data.aws_iam_role.external["api_handler"].name == "bt-test-APIHandlerRole"
      && data.aws_iam_role.external["db_monitoring"].name == "bt-test-db-monitoring"
      && data.aws_iam_role.external["quarantine_pruner_schedule"].name == "bt-test-QuarantinePrunerScheduleRole"
      && data.aws_iam_instance_profile.external[0].name == "bt-test-brainstore-instance-profile"
    )
    error_message = "Each lookup must read the default name that security's standalone run creates."
  }

  assert {
    condition     = length(aws_iam_role.api_handler) == 0 && length(aws_iam_instance_profile.brainstore) == 0
    error_message = "External mode must create no IAM."
  }
}

run "looks_up_only_the_roles_that_the_enabled_features_need" {
  command = plan
  module { source = "./modules/iam" }

  variables {
    create_iam        = false
    create_ai_gateway = false
  }

  assert {
    condition     = !contains(keys(data.aws_iam_role.external), "gateway_task") && !contains(keys(data.aws_iam_role.external), "quarantine_invoke") && !contains(keys(data.aws_iam_role.external), "quarantine_pruner_schedule")
    error_message = "A role whose feature is off must not be looked up."
  }
}

run "applies_sparse_name_and_path_overrides_to_lookups" {
  command = plan
  module { source = "./modules/iam" }

  variables {
    create_iam = false
    override_iam_names = {
      "role.api_handler"            = { name = "example-api", path = "/security/" }
      "instance_profile.brainstore" = { name = "example-brainstore-profile" }
    }
  }

  override_data {
    target = data.aws_iam_role.external["api_handler"]
    values = {
      arn  = "arn:aws:iam::123456789012:role/security/example-api"
      path = "/security/"
      tags = { BraintrustIAMOwner = "customer" }
    }
  }

  assert {
    condition = (
      data.aws_iam_role.external["api_handler"].name == "example-api"
      && data.aws_iam_role.external["brainstore"].name == "bt-test-brainstore-ec2-role"
      && data.aws_iam_instance_profile.external[0].name == "example-brainstore-profile"
      && output.role_names.api_handler == "example-api"
      && output.api_handler_role_arn == "arn:aws:iam::123456789012:role/security/example-api"
    )
    error_message = "An override must change only the fields it lists, and the other roles must keep their default names."
  }
}

run "applies_name_and_path_overrides_to_standalone_roles" {
  command = plan
  module { source = "./modules/iam" }

  variables {
    iam_owner = "customer"
    override_iam_names = {
      "role.api_handler"            = { name = "example-api", path = "/security/" }
      "instance_profile.brainstore" = { path = "/security/" }
    }
  }

  assert {
    condition = (
      aws_iam_role.api_handler[0].name == "example-api"
      && aws_iam_role.api_handler[0].path == "/security/"
      && aws_iam_role.brainstore[0].name == "bt-test-brainstore-ec2-role"
      && aws_iam_instance_profile.brainstore[0].name == "bt-test-brainstore-instance-profile"
      && aws_iam_instance_profile.brainstore[0].path == "/security/"
    )
    error_message = "The names and paths that security creates must match the ones that infrastructure looks up."
  }
}

run "leaves_role_paths_unset_without_an_override" {
  command = plan
  module { source = "./modules/iam" }

  variables {
    iam_owner = "customer"
  }

  # A set path would force a replacement on a state that never wrote it.
  assert {
    condition     = output.role_names.api_handler == "bt-test-APIHandlerRole" && aws_iam_role.api_handler[0].path == null
    error_message = "A role without a path override must leave path unset, so existing managed roles don't change."
  }
}

run "reads_existing_iam_references_back" {
  command = plan
  module { source = "./modules/iam" }

  variables {
    create_iam = false
    existing_iam = {
      "role.gateway_task"           = { arn = "arn:aws:iam::123456789012:role/security/example-gateway" }
      "instance_profile.brainstore" = { arn = "arn:aws:iam::123456789012:instance-profile/example-profile" }
    }
  }

  override_data {
    target = data.aws_iam_role.external["gateway_task"]
    values = {
      arn  = "arn:aws:iam::123456789012:role/security/example-gateway"
      path = "/security/"
      tags = { BraintrustIAMOwner = "customer" }
    }
  }

  override_data {
    target = data.aws_iam_instance_profile.external[0]
    values = {
      arn      = "arn:aws:iam::123456789012:instance-profile/example-profile"
      path     = "/"
      role_arn = "arn:aws:iam::123456789012:role/mock"
    }
  }

  assert {
    condition = (
      data.aws_iam_role.external["gateway_task"].name == "example-gateway"
      && data.aws_iam_instance_profile.external[0].name == "example-profile"
      && output.gateway_task_role_arn == "arn:aws:iam::123456789012:role/security/example-gateway"
    )
    error_message = "A role or instance profile supplied by ARN must be looked up by the name in that ARN."
  }
}

run "rejects_existing_iam_arn_that_the_lookup_doesnt_return" {
  command = plan
  module { source = "./modules/iam" }

  variables {
    create_iam = false
    existing_iam = {
      "role.gateway_task" = { arn = "arn:aws:iam::123456789012:role/security/example-gateway" }
    }
  }

  override_data {
    target = data.aws_iam_role.external["gateway_task"]
    values = {
      arn  = "arn:aws:iam::123456789012:role/other/example-gateway"
      path = "/"
      tags = { BraintrustIAMOwner = "customer" }
    }
  }

  expect_failures = [data.aws_iam_role.external["gateway_task"]]
}

run "rejects_role_in_another_account" {
  command = plan
  module { source = "./modules/iam" }

  variables {
    create_iam = false
  }

  override_data {
    target = data.aws_iam_role.external["api_handler"]
    values = {
      arn  = "arn:aws:iam::999999999999:role/bt-test-APIHandlerRole"
      path = "/"
      tags = { BraintrustIAMOwner = "customer" }
    }
  }

  expect_failures = [data.aws_iam_role.external["api_handler"]]
}

run "rejects_role_in_another_partition" {
  command = plan
  module { source = "./modules/iam" }

  variables {
    create_iam = false
  }

  override_data {
    target = data.aws_iam_role.external["api_handler"]
    values = {
      arn  = "arn:aws-cn:iam::123456789012:role/bt-test-APIHandlerRole"
      path = "/"
      tags = { BraintrustIAMOwner = "customer" }
    }
  }

  expect_failures = [data.aws_iam_role.external["api_handler"]]
}

run "rejects_role_with_a_path_that_differs_from_the_expected_one" {
  command = plan
  module { source = "./modules/iam" }

  variables {
    create_iam = false
  }

  override_data {
    target = data.aws_iam_role.external["api_handler"]
    values = {
      arn  = "arn:aws:iam::123456789012:role/bt-test-APIHandlerRole"
      path = "/other/"
      tags = { BraintrustIAMOwner = "customer" }
    }
  }

  expect_failures = [data.aws_iam_role.external["api_handler"]]
}

run "rejects_roles_that_resolve_to_the_same_name" {
  command = plan
  module { source = "./modules/iam" }

  variables {
    create_iam = false
    override_iam_names = {
      "role.billing_cron_schedule" = { name = "bt-test-AutomationCronScheduleRole" }
    }
  }

  expect_failures = [data.aws_caller_identity.current]
}

run "rejects_case_insensitive_name_collision" {
  command = plan
  module { source = "./modules/iam" }

  variables {
    iam_owner = "customer"
    override_iam_names = {
      "role.billing_cron" = { name = "BT-TEST-AUTOMATIONCRONROLE" }
    }
  }

  expect_failures = [data.aws_caller_identity.current]
}

run "rejects_case_insensitive_name_collision_in_external_mode" {
  command = plan
  module { source = "./modules/iam" }

  variables {
    create_iam = false
    override_iam_names = {
      "role.billing_cron" = { name = "BT-TEST-AUTOMATIONCRONROLE" }
    }
  }

  expect_failures = [data.aws_caller_identity.current]
}

run "rejects_scheduler_roles_that_share_an_existing_iam_arn" {
  command = plan
  module { source = "./modules/iam" }

  variables {
    create_iam = false
    existing_iam = {
      "role.automation_cron_schedule" = { arn = "arn:aws:iam::123456789012:role/shared-schedule" }
      "role.billing_cron_schedule"    = { arn = "arn:aws:iam::123456789012:role/shared-schedule" }
    }
  }

  override_data {
    target = data.aws_iam_role.external["automation_cron_schedule"]
    values = {
      arn  = "arn:aws:iam::123456789012:role/shared-schedule"
      path = "/"
      tags = { BraintrustIAMOwner = "customer" }
    }
  }

  override_data {
    target = data.aws_iam_role.external["billing_cron_schedule"]
    values = {
      arn  = "arn:aws:iam::123456789012:role/shared-schedule"
      path = "/"
      tags = { BraintrustIAMOwner = "customer" }
    }
  }

  expect_failures = [data.aws_caller_identity.current]
}

run "rejects_unknown_override_key" {
  command = plan
  module { source = "./modules/iam" }

  variables {
    create_iam         = false
    override_iam_names = { "role.api_handlr" = { name = "typo" } }
  }

  expect_failures = [var.override_iam_names]
}

run "rejects_override_of_the_default_role" {
  command = plan
  module { source = "./modules/iam" }

  variables {
    iam_owner          = "customer"
    override_iam_names = { "role.default" = { name = "example-default" } }
  }

  expect_failures = [var.override_iam_names]
}

run "rejects_unknown_override_field" {
  command = plan
  module { source = "./modules/iam" }

  variables {
    create_iam         = false
    override_iam_names = { "role.api_handler" = { arn = "arn:aws:iam::123456789012:role/x" } }
  }

  expect_failures = [var.override_iam_names]
}

run "rejects_empty_override_name" {
  command = plan
  module { source = "./modules/iam" }

  variables {
    create_iam         = false
    override_iam_names = { "role.api_handler" = { name = "" } }
  }

  expect_failures = [var.override_iam_names]
}

run "rejects_role_name_longer_than_64_characters" {
  command = plan
  module { source = "./modules/iam" }

  variables {
    create_iam         = false
    override_iam_names = { "role.api_handler" = { name = "a2345678901234567890123456789012345678901234567890123456789012345" } }
  }

  expect_failures = [var.override_iam_names]
}

run "rejects_override_path_without_slashes" {
  command = plan
  module { source = "./modules/iam" }

  variables {
    create_iam         = false
    override_iam_names = { "role.api_handler" = { path = "security" } }
  }

  expect_failures = [var.override_iam_names]
}

run "rejects_unknown_existing_iam_key" {
  command = plan
  module { source = "./modules/iam" }

  variables {
    create_iam   = false
    existing_iam = { "role.ai_proxy_invoke" = { arn = "arn:aws:iam::123456789012:role/x" } }
  }

  expect_failures = [var.existing_iam]
}

run "rejects_unknown_existing_iam_field" {
  command = plan
  module { source = "./modules/iam" }

  variables {
    create_iam   = false
    existing_iam = { "role.api_handler" = { name = "bt-test-APIHandlerRole" } }
  }

  expect_failures = [var.existing_iam]
}

run "rejects_existing_iam_arn_that_is_not_a_role_arn" {
  command = plan
  module { source = "./modules/iam" }

  variables {
    create_iam   = false
    existing_iam = { "role.api_handler" = { arn = "arn:aws:iam::123456789012:instance-profile/x" } }
  }

  expect_failures = [var.existing_iam]
}

run "rejects_override_name_that_contradicts_the_existing_iam_arn" {
  command = plan
  module { source = "./modules/iam" }

  variables {
    create_iam         = false
    override_iam_names = { "role.api_handler" = { name = "example-api" } }
    existing_iam       = { "role.api_handler" = { arn = "arn:aws:iam::123456789012:role/other-name" } }
  }

  expect_failures = [var.existing_iam]
}

run "rejects_override_path_that_conflicts_with_existing_iam" {
  command = plan
  module { source = "./modules/iam" }

  variables {
    create_iam         = false
    override_iam_names = { "role.api_handler" = { path = "/other/" } }
    existing_iam       = { "role.api_handler" = { arn = "arn:aws:iam::123456789012:role/security/bt-test-APIHandlerRole" } }
  }

  expect_failures = [var.existing_iam]
}

run "accepts_override_path_that_matches_existing_iam" {
  command = plan
  module { source = "./modules/iam" }

  variables {
    create_iam         = false
    override_iam_names = { "role.api_handler" = { path = "/security/" } }
    existing_iam       = { "role.api_handler" = { arn = "arn:aws:iam::123456789012:role/security/bt-test-APIHandlerRole" } }
  }

  override_data {
    target = data.aws_iam_role.external["api_handler"]
    values = {
      arn  = "arn:aws:iam::123456789012:role/security/bt-test-APIHandlerRole"
      path = "/security/"
      tags = { BraintrustIAMOwner = "customer" }
    }
  }

  assert {
    condition     = output.api_handler_role_arn == "arn:aws:iam::123456789012:role/security/bt-test-APIHandlerRole"
    error_message = "An override path that agrees with the existing_iam ARN must pass."
  }
}

run "treats_empty_kms_key_arn_as_null" {
  command = plan
  module { source = "./modules/iam" }

  variables {
    iam_owner   = "customer"
    kms_key_arn = ""
  }

  assert {
    condition = (
      jsondecode(aws_iam_role_policy.brainstore_kms_policy[0].policy).Statement == [{
        Effect    = "Allow"
        Action    = ["kms:Encrypt", "kms:Decrypt", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:DescribeKey"]
        Resource  = ["arn:aws:kms:us-east-1:123456789012:key/*"]
        Condition = { "ForAnyValue:StringEquals" = { "kms:ResourceAliases" = "alias/braintrust/bt-test" } }
      }]
    )
    error_message = "An empty kms_key_arn must render the same alias scope as null, not an empty exact ARN."
  }
}

run "rejects_instance_profile_arn_and_name_that_disagree" {
  command = plan
  module { source = "./modules/iam" }

  variables {
    create_iam = false
    existing_iam = {
      "instance_profile.brainstore" = { arn = "arn:aws:iam::123456789012:instance-profile/one", name = "two" }
    }
  }

  expect_failures = [var.existing_iam]
}

run "rejects_existing_iam_when_the_module_creates_iam" {
  command = plan
  module { source = "./modules/iam" }

  variables {
    iam_owner    = "customer"
    existing_iam = { "role.api_handler" = { arn = "arn:aws:iam::123456789012:role/x" } }
  }

  expect_failures = [var.existing_iam]
}

run "rejects_override_iam_names_when_the_root_creates_iam" {
  command = plan

  variables {
    braintrust_org_name    = "test-org"
    primary_org_name       = "test-org"
    brainstore_license_key = "test-license"
    override_iam_names     = { "role.api_handler" = { name = "example-api" } }
  }


  override_data {
    target = module.kms[0].data.aws_iam_role.autoscaling_service_linked_role
    values = { arn = "arn:aws:iam::123456789012:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling" }
  }

  expect_failures = [var.override_iam_names]
}

run "rejects_existing_iam_when_the_root_creates_iam" {
  command = plan

  variables {
    braintrust_org_name    = "test-org"
    primary_org_name       = "test-org"
    brainstore_license_key = "test-license"
    existing_iam           = { "role.api_handler" = { arn = "arn:aws:iam::123456789012:role/x" } }
  }


  override_data {
    target = module.kms[0].data.aws_iam_role.autoscaling_service_linked_role
    values = { arn = "arn:aws:iam::123456789012:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling" }
  }

  expect_failures = [var.existing_iam]
}
