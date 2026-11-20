# EventBridge Scheduler runs the four scheduled Lambda functions. These runs
# cover the schedules in modules/services and the invocation roles in
# modules/iam.
#
# A plan can't prove that the old EventBridge rules, targets and Lambda
# permissions are gone. scripts/check-iam-dependencies checks that on the graph,
# and the upgrade test (v7_upgrade.tftest.hcl) proves the destroys against the
# parent. Mocks can't prove that Scheduler substitutes the context attributes
# or accepts a new role, so the sandbox covers those.

mock_provider "aws" {
  source = "./tests/mocks/aws"

  # External IAM mode looks roles up. This is a role and instance profile that
  # security created, for the runs below with create_iam = false.
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
  region          = "us-east-1"
  account_id      = "123456789012"
  deployment_name = "bt-test"

  # modules/services inputs.
  braintrust_org_name         = "test-org"
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
  custom_tags                 = { team = "platform" }
  enable_ecs_api              = true

  # The pruner needs a quarantine VPC.
  use_quarantine_vpc             = true
  quarantine_vpc_id              = "vpc-quarantine"
  quarantine_vpc_private_subnets = ["subnet-q1", "subnet-q2", "subnet-q3"]
  quarantine_pruner_role_arn     = "arn:aws:iam::123456789012:role/bt-test-QuarantinePrunerRole"
  quarantine_warmup_role_arn     = "arn:aws:iam::123456789012:role/bt-test-QuarantineWarmupRole"

  # Every role gets its own ARN, so a schedule on the wrong role fails an assertion.
  api_handler_role_arn                = "arn:aws:iam::123456789012:role/bt-test-APIHandlerRole"
  automation_cron_role_arn            = "arn:aws:iam::123456789012:role/bt-test-AutomationCronRole"
  billing_cron_role_arn               = "arn:aws:iam::123456789012:role/bt-test-BillingCronRole"
  catchup_etl_role_arn                = "arn:aws:iam::123456789012:role/bt-test-CatchupETLRole"
  migrate_database_role_arn           = "arn:aws:iam::123456789012:role/bt-test-MigrateDatabaseFunctionRole"
  automation_cron_schedule_role_arn   = "arn:aws:iam::123456789012:role/bt-test-AutomationCronScheduleRole"
  billing_cron_schedule_role_arn      = "arn:aws:iam::123456789012:role/bt-test-BillingCronScheduleRole"
  catchup_etl_schedule_role_arn       = "arn:aws:iam::123456789012:role/bt-test-CatchupETLScheduleRole"
  quarantine_pruner_schedule_role_arn = "arn:aws:iam::123456789012:role/bt-test-QuarantinePrunerScheduleRole"

  # modules/iam inputs. The Scheduler roles use none of the created resources,
  # but the other roles in the module check that they're set.
  created_resources = {
    kms_key_arn                               = "arn:aws:kms:us-east-1:123456789012:key/11111111-1111-1111-1111-111111111111"
    database_url_secret_arn                   = "arn:aws:secretsmanager:us-east-1:123456789012:secret:bt-test/DatabaseUrl-AbCdEf"
    function_tools_secret_arn                 = "arn:aws:secretsmanager:us-east-1:123456789012:secret:bt-test/FunctionToolsSecret-AbCdEf"
    redis_url_secret_arn                      = "arn:aws:secretsmanager:us-east-1:123456789012:secret:bt-test/RedisUrl-AbCdEf"
    brainstore_license_key_secret_arn         = "arn:aws:secretsmanager:us-east-1:123456789012:secret:bt-test/brainstore/license-key-AbCdEf"
    internal_observability_api_key_secret_arn = ""
    database_secret_arn                       = "arn:aws:secretsmanager:us-east-1:123456789012:secret:bt-test/DatabaseSecret-AbCdEf"
    brainstore_s3_bucket_arn                  = "arn:aws:s3:::bt-test-brainstore-1"
    code_bundle_s3_bucket_arn                 = "arn:aws:s3:::bt-test-code-bundles-1"
    lambda_responses_s3_bucket_arn            = "arn:aws:s3:::bt-test-lambda-responses-1"
    quarantine_vpc_id                         = "vpc-87654321"
  }
  brainstore_deployment_log_group_arn = "arn:aws:logs:us-east-1:123456789012:log-group:/braintrust/bt-test/bt-test-BrainstoreDeployment"
  brainstore_asg_names                = ["bt-test-brainstore-reader-123"]
}

run "schedules_send_the_scheduled_event_envelope" {
  command = plan
  module { source = "./modules/services" }

  variables {
    enable_quarantine_pruner = true
  }

  # Scheduler substitutes only the literal placeholders. jsonencode() would have
  # written the angle brackets as \u003c and \u003e.
  assert {
    condition = alltrue([
      for input in [
        aws_scheduler_schedule.automation_cron.target[0].input,
        aws_scheduler_schedule.billing_cron.target[0].input,
        aws_scheduler_schedule.catchup_etl.target[0].input,
        aws_scheduler_schedule.quarantine_pruner[0].target[0].input,
        ] : (
        strcontains(input, "<aws.scheduler.execution-id>")
        && strcontains(input, "<aws.scheduler.scheduled-time>")
        && strcontains(input, "<aws.scheduler.schedule-arn>")
        && !strcontains(input, "\\u003c")
        && !strcontains(input, "\\u003e")
      )
    ])
    error_message = "Every schedule input must contain the literal <aws.scheduler.execution-id>, <aws.scheduler.scheduled-time> and <aws.scheduler.schedule-arn> placeholders, unescaped."
  }

  assert {
    condition = alltrue([
      for input in [
        aws_scheduler_schedule.automation_cron.target[0].input,
        aws_scheduler_schedule.billing_cron.target[0].input,
        aws_scheduler_schedule.catchup_etl.target[0].input,
        aws_scheduler_schedule.quarantine_pruner[0].target[0].input,
        ] : (
        jsondecode(input) == {
          "version"     = "0"
          "id"          = "<aws.scheduler.execution-id>"
          "detail-type" = "Scheduled Event"
          "source"      = "aws.events"
          "account"     = "123456789012"
          "time"        = "<aws.scheduler.scheduled-time>"
          "region"      = "us-east-1"
          "resources"   = ["<aws.scheduler.schedule-arn>"]
          "detail"      = {}
        }
      )
    ])
    error_message = "Every schedule must send the EventBridge scheduled-event envelope with the deployment account and region."
  }
}

run "schedules_keep_the_rule_names_and_expressions" {
  command = plan
  module { source = "./modules/services" }

  variables {
    enable_quarantine_pruner = true
  }

  assert {
    condition = (
      aws_scheduler_schedule.automation_cron.name == "bt-test-automation-cron-schedule"
      && aws_scheduler_schedule.billing_cron.name == "bt-test-billing-cron-schedule"
      && aws_scheduler_schedule.catchup_etl.name == "bt-test-catchup-etl-schedule"
      && aws_scheduler_schedule.quarantine_pruner[0].name == "bt-test-quarantine-pruner-schedule"
    )
    error_message = "Each schedule must reuse the name of the rule it replaces."
  }

  assert {
    condition = (
      aws_scheduler_schedule.automation_cron.schedule_expression == "rate(10 minutes)"
      && aws_scheduler_schedule.billing_cron.schedule_expression == "rate(5 minutes)"
      && aws_scheduler_schedule.catchup_etl.schedule_expression == "rate(10 minutes)"
      && aws_scheduler_schedule.quarantine_pruner[0].schedule_expression == "rate(1 hour)"
    )
    error_message = "Each schedule must keep the rate of the rule it replaces."
  }

  assert {
    condition = alltrue([
      for schedule in [
        aws_scheduler_schedule.automation_cron,
        aws_scheduler_schedule.billing_cron,
        aws_scheduler_schedule.catchup_etl,
        aws_scheduler_schedule.quarantine_pruner[0],
        ] : (
        schedule.group_name == "bt-test-scheduled-jobs"
        && schedule.schedule_expression_timezone == "UTC"
        && schedule.flexible_time_window[0].mode == "OFF"
      )
    ])
    error_message = "Every schedule must sit in the shared group and run in UTC with no flexible window."
  }

  assert {
    condition     = aws_scheduler_schedule.quarantine_pruner[0].state == "ENABLED"
    error_message = "The pruner schedule must stay enabled in every mode. The handler returns early when the mode is off."
  }

  assert {
    condition = alltrue([
      for schedule in [
        aws_scheduler_schedule.automation_cron,
        aws_scheduler_schedule.billing_cron,
        aws_scheduler_schedule.catchup_etl,
        aws_scheduler_schedule.quarantine_pruner[0],
        ] : (
        schedule.target[0].retry_policy[0].maximum_event_age_in_seconds == 86400
        && schedule.target[0].retry_policy[0].maximum_retry_attempts == 185
        && length(schedule.target[0].dead_letter_config) == 0
      )
    ])
    error_message = "Every schedule must retry for 24 hours up to 185 times, as an EventBridge target does, and have no dead-letter queue."
  }
}

run "schedules_target_functions_by_name_with_their_own_role" {
  command = plan
  module { source = "./modules/services" }

  variables {
    enable_quarantine_pruner = true
  }

  # The function ARN is unknown until apply. A known value here shows the
  # schedule doesn't read it from the function, so it doesn't wait for the
  # function, the database migration or the Brainstore waiter.
  assert {
    condition = (
      aws_scheduler_schedule.automation_cron.target[0].arn == "arn:aws:lambda:us-east-1:123456789012:function:bt-test-AutomationCron"
      && aws_scheduler_schedule.billing_cron.target[0].arn == "arn:aws:lambda:us-east-1:123456789012:function:bt-test-BillingCron"
      && aws_scheduler_schedule.catchup_etl.target[0].arn == "arn:aws:lambda:us-east-1:123456789012:function:bt-test-CatchupETL"
      && aws_scheduler_schedule.quarantine_pruner[0].target[0].arn == "arn:aws:lambda:us-east-1:123456789012:function:bt-test-QuarantinePrunerFunction"
    )
    error_message = "Each schedule must target the unqualified ARN built from its function's name."
  }

  assert {
    condition = (
      aws_scheduler_schedule.automation_cron.target[0].role_arn == var.automation_cron_schedule_role_arn
      && aws_scheduler_schedule.billing_cron.target[0].role_arn == var.billing_cron_schedule_role_arn
      && aws_scheduler_schedule.catchup_etl.target[0].role_arn == var.catchup_etl_schedule_role_arn
      && aws_scheduler_schedule.quarantine_pruner[0].target[0].role_arn == var.quarantine_pruner_schedule_role_arn
    )
    error_message = "Each schedule must assume the invocation role it was given, so none shares a role."
  }

  assert {
    condition = (
      aws_scheduler_schedule.automation_cron.target[0].arn == "arn:aws:lambda:us-east-1:123456789012:function:${aws_lambda_function.automation_cron.function_name}"
      && aws_scheduler_schedule.billing_cron.target[0].arn == "arn:aws:lambda:us-east-1:123456789012:function:${aws_lambda_function.billing_cron.function_name}"
      && aws_scheduler_schedule.catchup_etl.target[0].arn == "arn:aws:lambda:us-east-1:123456789012:function:${aws_lambda_function.catchup_etl.function_name}"
      && aws_scheduler_schedule.quarantine_pruner[0].target[0].arn == "arn:aws:lambda:us-east-1:123456789012:function:${aws_lambda_function.quarantine_pruner[0].function_name}"
    )
    error_message = "Each target ARN must match the function it invokes."
  }
}

run "group_is_named_for_the_deployment_and_carries_its_tags" {
  command = plan
  module { source = "./modules/services" }

  assert {
    condition     = aws_scheduler_schedule_group.scheduled_jobs.name == "bt-test-scheduled-jobs"
    error_message = "The schedule group must be named <deployment_name>-scheduled-jobs, which the invocation role trust policies name by ARN."
  }

  assert {
    condition     = aws_scheduler_schedule_group.scheduled_jobs.tags["BraintrustDeploymentName"] == "bt-test" && aws_scheduler_schedule_group.scheduled_jobs.tags["team"] == "platform"
    error_message = "Schedules can't carry tags, so the group must carry the deployment name and the custom tags."
  }
}

run "omits_the_pruner_schedule_unless_the_pruner_is_enabled" {
  command = plan
  module { source = "./modules/services" }

  assert {
    condition     = length(aws_scheduler_schedule.quarantine_pruner) == 0 && length(aws_lambda_function.quarantine_pruner) == 0
    error_message = "The pruner schedule must exist only with the pruner."
  }
}

run "scheduler_roles_trust_scheduler_for_the_group_only" {
  command = plan
  module { source = "./modules/iam" }

  variables {
    enable_quarantine_vpc    = true
    enable_quarantine_pruner = true
  }

  assert {
    condition = alltrue([
      for role in [
        aws_iam_role.automation_cron_schedule[0],
        aws_iam_role.billing_cron_schedule[0],
        aws_iam_role.catchup_etl_schedule[0],
        aws_iam_role.quarantine_pruner_schedule[0],
        ] : (
        length(jsondecode(role.assume_role_policy).Statement) == 1
        && jsondecode(role.assume_role_policy).Statement[0].Effect == "Allow"
        && jsondecode(role.assume_role_policy).Statement[0].Action == "sts:AssumeRole"
        && jsondecode(role.assume_role_policy).Statement[0].Principal == { Service = "scheduler.amazonaws.com" }
      )
    ])
    error_message = "Each invocation role must trust only scheduler.amazonaws.com for sts:AssumeRole."
  }

  assert {
    condition = alltrue([
      for role in [
        aws_iam_role.automation_cron_schedule[0],
        aws_iam_role.billing_cron_schedule[0],
        aws_iam_role.catchup_etl_schedule[0],
        aws_iam_role.quarantine_pruner_schedule[0],
        ] : (
        jsondecode(role.assume_role_policy).Statement[0].Condition == {
          StringEquals = {
            "aws:SourceAccount" = "123456789012"
            "aws:SourceArn"     = "arn:aws:scheduler:us-east-1:123456789012:schedule-group/bt-test-scheduled-jobs"
          }
        }
      )
    ])
    error_message = "Each invocation role must trust Scheduler only for this account and the schedule group, which prevents a confused deputy."
  }
}

run "scheduler_roles_invoke_only_their_own_function" {
  command = plan
  module { source = "./modules/iam" }

  variables {
    enable_quarantine_vpc    = true
    enable_quarantine_pruner = true
  }

  assert {
    condition = (
      jsondecode(aws_iam_role_policy.automation_cron_schedule[0].policy).Statement == [{
        Action   = "lambda:InvokeFunction"
        Effect   = "Allow"
        Resource = "arn:aws:lambda:us-east-1:123456789012:function:bt-test-AutomationCron"
      }]
      && jsondecode(aws_iam_role_policy.billing_cron_schedule[0].policy).Statement == [{
        Action   = "lambda:InvokeFunction"
        Effect   = "Allow"
        Resource = "arn:aws:lambda:us-east-1:123456789012:function:bt-test-BillingCron"
      }]
      && jsondecode(aws_iam_role_policy.catchup_etl_schedule[0].policy).Statement == [{
        Action   = "lambda:InvokeFunction"
        Effect   = "Allow"
        Resource = "arn:aws:lambda:us-east-1:123456789012:function:bt-test-CatchupETL"
      }]
      && jsondecode(aws_iam_role_policy.quarantine_pruner_schedule[0].policy).Statement == [{
        Action   = "lambda:InvokeFunction"
        Effect   = "Allow"
        Resource = "arn:aws:lambda:us-east-1:123456789012:function:bt-test-QuarantinePrunerFunction"
      }]
    )
    error_message = "Each invocation role must be allowed lambda:InvokeFunction on its own function's unqualified ARN and nothing else."
  }

  assert {
    condition = (
      aws_iam_role_policy.automation_cron_schedule[0].role == aws_iam_role.automation_cron_schedule[0].name
      && aws_iam_role_policy.billing_cron_schedule[0].role == aws_iam_role.billing_cron_schedule[0].name
      && aws_iam_role_policy.catchup_etl_schedule[0].role == aws_iam_role.catchup_etl_schedule[0].name
      && aws_iam_role_policy.quarantine_pruner_schedule[0].role == aws_iam_role.quarantine_pruner_schedule[0].name
    )
    error_message = "Each invoke policy must sit on its own job's invocation role."
  }

  assert {
    condition = (
      aws_iam_role_policy.automation_cron_schedule[0].name == "bt-test-AutomationCronScheduleRolePolicy"
      && aws_iam_role_policy.billing_cron_schedule[0].name == "bt-test-BillingCronScheduleRolePolicy"
      && aws_iam_role_policy.catchup_etl_schedule[0].name == "bt-test-CatchupETLScheduleRolePolicy"
      && aws_iam_role_policy.quarantine_pruner_schedule[0].name == "bt-test-QuarantinePrunerScheduleRolePolicy"
    )
    error_message = "Each invoke policy must be named <deployment_name>-<Job>ScheduleRolePolicy."
  }
}

run "scheduler_roles_keep_the_permissions_boundary" {
  command = plan
  module { source = "./modules/iam" }

  variables {
    enable_quarantine_vpc    = true
    enable_quarantine_pruner = true
    permissions_boundary_arn = "arn:aws:iam::123456789012:policy/boundary"
  }

  assert {
    condition = alltrue([
      for role in [
        aws_iam_role.automation_cron_schedule[0],
        aws_iam_role.billing_cron_schedule[0],
        aws_iam_role.catchup_etl_schedule[0],
        aws_iam_role.quarantine_pruner_schedule[0],
      ] : role.permissions_boundary == "arn:aws:iam::123456789012:policy/boundary"
    ])
    error_message = "The invocation roles must respect the permissions boundary like every other role."
  }
}

run "scheduler_roles_omit_the_pruner_role_unless_the_pruner_is_enabled" {
  command = plan
  module { source = "./modules/iam" }

  assert {
    condition = (
      length(aws_iam_role.quarantine_pruner_schedule) == 0
      && length(aws_iam_role_policy.quarantine_pruner_schedule) == 0
      && output.quarantine_pruner_schedule_role_arn == null
      && length(aws_iam_role.automation_cron_schedule) == 1
      && length(aws_iam_role.billing_cron_schedule) == 1
      && length(aws_iam_role.catchup_etl_schedule) == 1
    )
    error_message = "Without the pruner, only its invocation role and policy may be skipped."
  }
}

run "scheduler_roles_are_absent_on_external_eks" {
  command = plan
  module { source = "./modules/iam" }

  variables {
    use_deployment_mode_external_eks = true
    enable_quarantine_vpc            = true
    enable_quarantine_pruner         = true
  }

  assert {
    condition = (
      length(aws_iam_role.automation_cron_schedule) == 0
      && length(aws_iam_role.billing_cron_schedule) == 0
      && length(aws_iam_role.catchup_etl_schedule) == 0
      && length(aws_iam_role.quarantine_pruner_schedule) == 0
    )
    error_message = "External EKS has no services module, so it needs no invocation roles."
  }
}

run "exposes_the_default_scheduler_role_names_without_creating_roles" {
  command = plan
  module { source = "./modules/iam" }

  variables {
    create_iam = false
  }

  assert {
    condition = (
      output.role_names.automation_cron_schedule == "bt-test-AutomationCronScheduleRole"
      && output.role_names.billing_cron_schedule == "bt-test-BillingCronScheduleRole"
      && output.role_names.catchup_etl_schedule == "bt-test-CatchupETLScheduleRole"
      && output.role_names.quarantine_pruner_schedule == "bt-test-QuarantinePrunerScheduleRole"
    )
    error_message = "role_names must publish the default Scheduler role names for lookup."
  }
}

run "rejects_the_pruner_without_its_schedule_role" {
  command = plan
  module { source = "./modules/services" }

  variables {
    enable_quarantine_pruner            = true
    quarantine_pruner_schedule_role_arn = null
  }

  expect_failures = [
    var.quarantine_pruner_schedule_role_arn,
  ]
}

run "schedules_target_functions_in_another_partition" {
  command = plan
  module { source = "./modules/services" }

  override_data {
    target = data.aws_partition.current
    values = { partition = "aws-us-gov" }
  }

  assert {
    condition = alltrue([
      for schedule in [
        aws_scheduler_schedule.automation_cron,
        aws_scheduler_schedule.billing_cron,
        aws_scheduler_schedule.catchup_etl,
      ] : startswith(schedule.target[0].arn, "arn:aws-us-gov:lambda:")
    ])
    error_message = "Each schedule target must take its partition from the deployment, not assume aws."
  }
}

run "scheduler_roles_use_another_partition_in_their_arns" {
  command = plan
  module { source = "./modules/iam" }

  variables {
    enable_quarantine_vpc    = true
    enable_quarantine_pruner = true
  }

  override_data {
    target = data.aws_partition.current
    values = { partition = "aws-us-gov" }
  }

  assert {
    condition = alltrue([
      for policy in [
        aws_iam_role_policy.automation_cron_schedule[0].policy,
        aws_iam_role_policy.billing_cron_schedule[0].policy,
        aws_iam_role_policy.catchup_etl_schedule[0].policy,
        aws_iam_role_policy.quarantine_pruner_schedule[0].policy,
      ] : startswith(jsondecode(policy).Statement[0].Resource, "arn:aws-us-gov:lambda:")
    ])
    error_message = "Each invoke policy must name its function in the deployment's partition."
  }

  assert {
    condition = alltrue([
      for role in [
        aws_iam_role.automation_cron_schedule[0],
        aws_iam_role.billing_cron_schedule[0],
        aws_iam_role.catchup_etl_schedule[0],
        aws_iam_role.quarantine_pruner_schedule[0],
      ] : startswith(jsondecode(role.assume_role_policy).Statement[0].Condition.StringEquals["aws:SourceArn"], "arn:aws-us-gov:scheduler:")
    ])
    error_message = "Each trust policy must name the schedule group in the deployment's partition."
  }
}
