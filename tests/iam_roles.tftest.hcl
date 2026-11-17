# Plan-mode tests for the roles that modules/iam owns: database monitoring, the
# Brainstore deployment waiter, API ECS execution and the gateway roles.
#
# The upgrade test (v7_upgrade.tftest.hcl) proves these roles move without a
# change. These runs pin the names, trust and policy documents it can't see,
# because the mock provider returns one fixed document for every
# aws_iam_policy_document.

mock_provider "aws" {
  source = "./tests/mocks/aws"
  mock_data "aws_partition" {
    defaults = { partition = "aws" }
  }
}

variables {
  deployment_name   = "bt-test"
  create_ai_gateway = true

  created_resources = {
    kms_key_arn                               = "arn:aws:kms:us-east-1:123456789012:key/11111111-1111-1111-1111-111111111111"
    database_url_secret_arn                   = "arn:aws:secretsmanager:us-east-1:123456789012:secret:bt-test/DatabaseUrl-AbCdEf"
    function_tools_secret_arn                 = "arn:aws:secretsmanager:us-east-1:123456789012:secret:bt-test/FunctionToolsSecret-AbCdEf"
    redis_url_secret_arn                      = "arn:aws:secretsmanager:us-east-1:123456789012:secret:bt-test/RedisUrl-AbCdEf"
    brainstore_license_key_secret_arn         = "arn:aws:secretsmanager:us-east-1:123456789012:secret:bt-test/brainstore/license-key-AbCdEf"
    internal_observability_api_key_secret_arn = ""
  }

  brainstore_deployment_log_group_arn = "arn:aws:logs:us-east-1:123456789012:log-group:/braintrust/bt-test/bt-test-BrainstoreDeployment"
  brainstore_asg_names                = ["bt-test-brainstore-reader-123", "bt-test-brainstore-writer-456"]
}

run "creates_every_role_with_its_released_name" {
  command = plan
  module { source = "./modules/iam" }

  assert {
    condition = (
      aws_iam_role.db_monitoring[0].name == "bt-test-db-monitoring"
      && aws_iam_role.brainstore_deployment_waiter[0].name == "bt-test-brainstore-deployment"
      && aws_iam_role.api_ecs_task_execution[0].name == "bt-test-api-ecs-task-exec"
      && aws_iam_role.gateway_task_execution[0].name == "bt-test-gateway-task-exec"
      && aws_iam_role.gateway_task[0].name == "bt-test-gateway-task"
    )
    error_message = "Each role must keep the physical name that existing stacks have."
  }

  assert {
    condition     = output.role_names == local.role_names && output.role_names.gateway_task == "bt-test-gateway-task"
    error_message = "role_names must publish the same names that the roles use."
  }

  assert {
    condition = (
      aws_iam_role_policy.api_ecs_task_execution_secrets[0].name == "bt-test-api-ecs-task-exec-secrets"
      && aws_iam_role_policy.gateway_task_execution_secrets[0].name == "bt-test-gateway-task-exec-secrets"
      && aws_iam_role_policy.gateway_task_execution_redis_secret[0].name == "bt-test-gateway-task-exec-redis-secret"
      && aws_iam_role_policy.gateway_task_customer_assume_role[0].name == "bt-test-gateway-customer-assume-role"
    )
    error_message = "Each named policy must keep the name that existing stacks have."
  }
}

run "trusts_only_the_service_that_runs_each_role" {
  command = plan
  module { source = "./modules/iam" }

  assert {
    condition     = jsondecode(aws_iam_role.db_monitoring[0].assume_role_policy).Statement[0].Principal.Service == "monitoring.rds.amazonaws.com"
    error_message = "Only RDS enhanced monitoring may assume the database monitoring role."
  }

  assert {
    condition     = jsondecode(aws_iam_role.brainstore_deployment_waiter[0].assume_role_policy).Statement[0].Principal.Service == "lambda.amazonaws.com"
    error_message = "Only Lambda may assume the waiter role."
  }

  assert {
    condition = (
      data.aws_iam_policy_document.ecs_task_assume_role.statement[0].actions == toset(["sts:AssumeRole"])
      && one(data.aws_iam_policy_document.ecs_task_assume_role.statement[0].principals).identifiers == toset(["ecs-tasks.amazonaws.com"])
    )
    error_message = "Only ECS tasks may assume the API execution and gateway roles."
  }

  assert {
    condition = alltrue([
      for role in [aws_iam_role.api_ecs_task_execution[0], aws_iam_role.gateway_task_execution[0], aws_iam_role.gateway_task[0]] :
      role.assume_role_policy == data.aws_iam_policy_document.ecs_task_assume_role.json
    ])
    error_message = "The API execution and gateway roles must use the shared ECS trust document."
  }
}

run "waiter_refreshes_only_named_and_tagged_asgs" {
  command = plan
  module { source = "./modules/iam" }

  assert {
    condition     = jsondecode(aws_iam_role_policy.brainstore_deployment_waiter[0].policy).Statement[1].Resource == ["arn:aws:autoscaling:us-east-1:123456789012:autoScalingGroup:*:autoScalingGroupName/bt-test-brainstore-reader-123", "arn:aws:autoscaling:us-east-1:123456789012:autoScalingGroup:*:autoScalingGroupName/bt-test-brainstore-writer-456"]
    error_message = "The waiter may refresh only the fleets it was given."
  }

  assert {
    condition     = jsondecode(aws_iam_role_policy.brainstore_deployment_waiter[0].policy).Statement[1].Condition.StringEquals["autoscaling:ResourceTag/BraintrustDeploymentName"] == "bt-test"
    error_message = "The waiter may refresh only ASGs tagged with this deployment."
  }

  assert {
    condition     = jsondecode(aws_iam_role_policy.brainstore_deployment_waiter[0].policy).Statement[2].Resource == "arn:aws:logs:us-east-1:123456789012:log-group:/braintrust/bt-test/bt-test-BrainstoreDeployment:*"
    error_message = "The waiter may write only to its own log group."
  }
}

run "api_execution_policy_reads_every_secret_it_injects" {
  command = plan
  module { source = "./modules/iam" }

  variables {
    custom_ca_bundle_secret_arn            = "arn:aws:secretsmanager:us-east-1:123456789012:secret:ca-bundle-AbCdEf"
    custom_ca_bundle_kms_key_arn           = "arn:aws:kms:us-east-1:123456789012:key/22222222-2222-2222-2222-222222222222"
    internal_observability_enabled         = true
    existing_brainstore_license_key_secret = { arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:license-AbCdEf", kms_key_arn = "arn:aws:kms:us-east-1:123456789012:key/33333333-3333-3333-3333-333333333333" }
    created_resources = merge(var.created_resources, {
      internal_observability_api_key_secret_arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:bt-test/internal-observability/api-key-AbCdEf"
    })
  }

  assert {
    condition = jsondecode(aws_iam_role_policy.api_ecs_task_execution_secrets[0].policy).Statement[0].Resource == [
      "arn:aws:secretsmanager:us-east-1:123456789012:secret:bt-test/DatabaseUrl-AbCdEf",
      "arn:aws:secretsmanager:us-east-1:123456789012:secret:bt-test/FunctionToolsSecret-AbCdEf",
      "arn:aws:secretsmanager:us-east-1:123456789012:secret:bt-test/RedisUrl-AbCdEf",
      "arn:aws:secretsmanager:us-east-1:123456789012:secret:ca-bundle-AbCdEf",
      "arn:aws:secretsmanager:us-east-1:123456789012:secret:bt-test/internal-observability/api-key-AbCdEf",
      "arn:aws:secretsmanager:us-east-1:123456789012:secret:license-AbCdEf",
    ]
    error_message = "The execution role must read the database, function tools, Redis, CA bundle, observability and license secrets, in that order."
  }

  assert {
    condition = jsondecode(aws_iam_role_policy.api_ecs_task_execution_secrets[0].policy).Statement[1].Resource == [
      "arn:aws:kms:us-east-1:123456789012:key/11111111-1111-1111-1111-111111111111",
      "arn:aws:kms:us-east-1:123456789012:key/22222222-2222-2222-2222-222222222222",
      "arn:aws:kms:us-east-1:123456789012:key/33333333-3333-3333-3333-333333333333",
    ]
    error_message = "The execution role must decrypt with the data plane, CA bundle and license keys."
  }

  assert {
    condition     = jsondecode(aws_iam_role_policy.api_ecs_task_execution_secrets[0].policy).Statement[1].Condition.StringEquals["kms:ViaService"] == "secretsmanager.us-east-1.amazonaws.com"
    error_message = "The execution role may use these keys only through Secrets Manager."
  }
}

run "api_execution_policy_omits_optional_secrets_when_unset" {
  command = plan
  module { source = "./modules/iam" }

  assert {
    condition     = jsondecode(aws_iam_role_policy.api_ecs_task_execution_secrets[0].policy).Statement[0].Resource == [var.created_resources.database_url_secret_arn, var.created_resources.function_tools_secret_arn, var.created_resources.redis_url_secret_arn, var.created_resources.brainstore_license_key_secret_arn]
    error_message = "Without a CA bundle or observability, the execution role must read only the required secrets."
  }

  assert {
    condition     = jsondecode(aws_iam_role_policy.api_ecs_task_execution_secrets[0].policy).Statement[1].Resource == [var.created_resources.kms_key_arn]
    error_message = "Without a CA bundle or caller-supplied license, the execution role must decrypt with the data plane key only."
  }
}

run "gateway_execution_policies_read_license_and_redis_secrets" {
  command = plan
  module { source = "./modules/iam" }

  variables {
    internal_observability_enabled         = true
    existing_brainstore_license_key_secret = { arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:license-AbCdEf", kms_key_arn = "arn:aws:kms:us-east-1:123456789012:key/33333333-3333-3333-3333-333333333333" }
    created_resources = merge(var.created_resources, {
      internal_observability_api_key_secret_arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:bt-test/internal-observability/api-key-AbCdEf"
    })
  }

  assert {
    condition     = jsondecode(aws_iam_role_policy.gateway_task_execution_secrets[0].policy).Statement[0].Resource == ["arn:aws:secretsmanager:us-east-1:123456789012:secret:bt-test/internal-observability/api-key-AbCdEf", "arn:aws:secretsmanager:us-east-1:123456789012:secret:license-AbCdEf"]
    error_message = "The gateway execution role must read the observability and license secrets."
  }

  assert {
    condition     = jsondecode(aws_iam_role_policy.gateway_task_execution_secrets[0].policy).Statement[1].Resource == ["arn:aws:kms:us-east-1:123456789012:key/11111111-1111-1111-1111-111111111111", "arn:aws:kms:us-east-1:123456789012:key/33333333-3333-3333-3333-333333333333"]
    error_message = "The gateway execution role must decrypt with the data plane and license keys."
  }

  assert {
    condition     = jsondecode(aws_iam_role_policy.gateway_task_execution_redis_secret[0].policy).Statement[0].Resource == "arn:aws:secretsmanager:us-east-1:123456789012:secret:bt-test/RedisUrl-AbCdEf" && jsondecode(aws_iam_role_policy.gateway_task_execution_redis_secret[0].policy).Statement[1].Resource == "arn:aws:kms:us-east-1:123456789012:key/11111111-1111-1111-1111-111111111111"
    error_message = "The gateway execution role must read the Redis URL secret with the data plane key."
  }
}

run "gateway_execution_policy_skips_observability_secret_when_disabled" {
  command = plan
  module { source = "./modules/iam" }

  assert {
    condition     = jsondecode(aws_iam_role_policy.gateway_task_execution_secrets[0].policy).Statement[0].Resource == [var.created_resources.brainstore_license_key_secret_arn]
    error_message = "Without observability, the gateway execution role must read only the license secret."
  }
}

run "gateway_execution_role_has_no_custom_ca_bundle_policy_when_unset" {
  command = plan
  module { source = "./modules/iam" }

  assert {
    condition     = length(aws_iam_role_policy.gateway_task_execution_custom_ca_bundle_secret) == 0
    error_message = "Without a CA bundle, the gateway must have no CA bundle policy."
  }
}

run "gateway_execution_role_reads_custom_ca_bundle_and_its_key" {
  command = plan
  module { source = "./modules/iam" }

  variables {
    custom_ca_bundle_secret_arn  = "arn:aws:secretsmanager:us-east-1:123456789012:secret:ca-bundle-AbCdEf"
    custom_ca_bundle_kms_key_arn = "arn:aws:kms:us-east-1:123456789012:key/22222222-2222-2222-2222-222222222222"
  }

  assert {
    condition     = jsondecode(aws_iam_role_policy.gateway_task_execution_custom_ca_bundle_secret[0].policy).Statement[0].Resource == "arn:aws:secretsmanager:us-east-1:123456789012:secret:ca-bundle-AbCdEf" && jsondecode(aws_iam_role_policy.gateway_task_execution_custom_ca_bundle_secret[0].policy).Statement[1].Resource == "arn:aws:kms:us-east-1:123456789012:key/22222222-2222-2222-2222-222222222222"
    error_message = "The gateway execution role must read the CA bundle secret and decrypt it with its key."
  }
}

run "gateway_task_assumes_any_role_when_no_allowlist_is_set" {
  command = plan
  module { source = "./modules/iam" }

  assert {
    condition     = jsondecode(aws_iam_role_policy.gateway_task_customer_assume_role[0].policy).Statement[0].Resource == ["*"]
    error_message = "An empty Bedrock allowlist must keep the legacy wildcard."
  }

  assert {
    condition     = jsondecode(aws_iam_role_policy.gateway_task_customer_assume_role[0].policy).Statement[0].Condition.StringLike["sts:ExternalId"] == "bt:*"
    error_message = "The gateway may assume customer roles only with a Braintrust external ID."
  }
}

run "gateway_task_assumes_only_listed_bedrock_roles" {
  command = plan
  module { source = "./modules/iam" }

  variables {
    ai_gateway_bedrock_assume_role_arns = ["arn:aws:iam::210987654321:role/bedrock"]
  }

  assert {
    condition     = jsondecode(aws_iam_role_policy.gateway_task_customer_assume_role[0].policy).Statement[0].Resource == ["arn:aws:iam::210987654321:role/bedrock"]
    error_message = "A Bedrock allowlist must replace the wildcard."
  }
}

run "gateway_diagnostics_need_a_log_group_and_ecs_exec" {
  command = plan
  module { source = "./modules/iam" }

  variables {
    diagnostics_transcript_log_group_name = "/braintrust-byoc/test/diagnostics"
  }

  assert {
    condition     = length(aws_iam_role_policy.gateway_task_diagnostics_transcripts) == 0 && length(aws_iam_role_policy.gateway_task_diagnostics_execute_command) == 0
    error_message = "A log group alone must not enable gateway diagnostics."
  }
}

run "gateway_diagnostics_write_only_to_the_named_log_group" {
  command = plan
  module { source = "./modules/iam" }

  variables {
    diagnostics_transcript_log_group_name = "/braintrust-byoc/test/diagnostics"
    ai_gateway_enable_execute_command     = true
  }

  assert {
    condition     = jsondecode(aws_iam_role_policy.gateway_task_diagnostics_transcripts[0].policy).Statement[1].Resource == "arn:aws:logs:us-east-1:123456789012:log-group:/braintrust-byoc/test/diagnostics:*"
    error_message = "Transcript delivery must be restricted to the exact log group."
  }

  assert {
    condition     = toset(jsondecode(aws_iam_role_policy.gateway_task_diagnostics_transcripts[0].policy).Statement[1].Action) == toset(["logs:CreateLogStream", "logs:DescribeLogStreams", "logs:PutLogEvents"])
    error_message = "Transcript delivery must not create or delete log groups."
  }

  assert {
    condition     = length(aws_iam_role_policy.gateway_task_diagnostics_execute_command) == 1
    error_message = "ECS Exec with a transcript destination must also grant the SSM message channels."
  }
}

run "gateway_exec_without_a_log_group_keeps_legacy_permissions" {
  command = plan
  module { source = "./modules/iam" }

  variables {
    ai_gateway_enable_execute_command = true
  }

  assert {
    condition     = length(aws_iam_role_policy.gateway_task_diagnostics_transcripts) == 0 && length(aws_iam_role_policy.gateway_task_diagnostics_execute_command) == 0
    error_message = "Without a log group, ECS Exec must not add diagnostics policies."
  }
}

run "roles_keep_the_permissions_boundary" {
  command = plan
  module { source = "./modules/iam" }

  variables {
    permissions_boundary_arn = "arn:aws:iam::123456789012:policy/boundary"
  }

  assert {
    condition = alltrue([
      for role in [aws_iam_role.db_monitoring[0], aws_iam_role.brainstore_deployment_waiter[0], aws_iam_role.api_ecs_task_execution[0], aws_iam_role.gateway_task_execution[0], aws_iam_role.gateway_task[0]] :
      role.permissions_boundary == "arn:aws:iam::123456789012:policy/boundary"
    ])
    error_message = "Every role must carry the permissions boundary."
  }
}

# The source modules disagree on whether a caller's BraintrustDeploymentName
# tag overrides the deployment name. Each role keeps its source order.
run "roles_keep_the_tag_order_of_their_source_modules" {
  command = plan
  module { source = "./modules/iam" }

  variables {
    custom_tags = { BraintrustDeploymentName = "caller", team = "platform" }
  }

  assert {
    condition = (
      aws_iam_role.db_monitoring[0].tags.BraintrustDeploymentName == "caller"
      && aws_iam_role.api_ecs_task_execution[0].tags.BraintrustDeploymentName == "caller"
      && aws_iam_role.gateway_task[0].tags.BraintrustDeploymentName == "caller"
    )
    error_message = "Roles from modules that merge the caller's tags last must keep the caller's value."
  }

  assert {
    condition     = aws_iam_role.brainstore_deployment_waiter[0].tags.BraintrustDeploymentName == "bt-test"
    error_message = "The waiter role must keep the deployment name over the caller's tag."
  }

  assert {
    condition     = aws_iam_role.api_ecs_task_execution[0].tags.Name == "bt-test-api-ecs-task-exec" && aws_iam_role.gateway_task[0].tags.Name == "bt-test-gateway-task" && aws_iam_role.gateway_task[0].tags.team == "platform"
    error_message = "ECS roles must keep their Name tag and the caller's tags."
  }
}

run "creates_no_roles_when_create_iam_is_false" {
  command = plan
  module { source = "./modules/iam" }

  variables {
    create_iam = false
  }

  assert {
    condition = (
      length(aws_iam_role.db_monitoring) == 0
      && length(aws_iam_role.brainstore_deployment_waiter) == 0
      && length(aws_iam_role.api_ecs_task_execution) == 0
      && length(aws_iam_role.gateway_task_execution) == 0
      && length(aws_iam_role.gateway_task) == 0
      && length(aws_iam_role_policy.gateway_task_customer_assume_role) == 0
    )
    error_message = "create_iam = false must create no roles or policies."
  }

  assert {
    condition     = output.role_names.db_monitoring == "bt-test-db-monitoring" && output.db_monitoring_role_arn == null && output.gateway_task_role_arn == null
    error_message = "Names must stay available when nothing is created, and ARNs must be null."
  }
}

run "skips_the_gateway_roles_without_a_gateway" {
  command = plan
  module { source = "./modules/iam" }

  variables {
    create_ai_gateway = false
  }

  assert {
    condition     = length(aws_iam_role.gateway_task_execution) == 0 && length(aws_iam_role.gateway_task) == 0 && length(aws_iam_role.api_ecs_task_execution) == 1
    error_message = "Without a gateway, only the gateway roles may be skipped."
  }
}

run "external_eks_keeps_only_the_database_monitoring_role" {
  command = plan
  module { source = "./modules/iam" }

  variables {
    use_deployment_mode_external_eks = true
  }

  assert {
    condition = (
      length(aws_iam_role.db_monitoring) == 1
      && length(aws_iam_role.brainstore_deployment_waiter) == 0
      && length(aws_iam_role.api_ecs_task_execution) == 0
      && length(aws_iam_role.gateway_task_execution) == 0
      && length(aws_iam_role.gateway_task) == 0
    )
    error_message = "External EKS has no waiter, API ECS service or gateway, so only database monitoring remains."
  }
}

run "rejects_bedrock_role_that_is_not_an_iam_role_arn" {
  command = plan
  module { source = "./modules/iam" }

  variables {
    ai_gateway_bedrock_assume_role_arns = ["arn:aws:s3:::bucket"]
  }

  expect_failures = [var.ai_gateway_bedrock_assume_role_arns]
}

run "rejects_wildcard_diagnostics_log_group" {
  command = plan
  module { source = "./modules/iam" }

  variables {
    diagnostics_transcript_log_group_name = "/braintrust/*"
  }

  expect_failures = [var.diagnostics_transcript_log_group_name]
}

run "rejects_api_execution_role_without_the_database_url_secret" {
  command = plan
  module { source = "./modules/iam" }

  variables {
    created_resources = merge(var.created_resources, { database_url_secret_arn = null })
  }

  expect_failures = [aws_iam_role.api_ecs_task_execution[0]]
}

run "rejects_api_execution_role_without_the_observability_secret_when_enabled" {
  command = plan
  module { source = "./modules/iam" }

  variables {
    internal_observability_enabled = true
    created_resources              = merge(var.created_resources, { internal_observability_api_key_secret_arn = null })
  }

  # The gateway execution role reads the same secret.
  expect_failures = [aws_iam_role.api_ecs_task_execution[0], aws_iam_role.gateway_task_execution[0]]
}

run "rejects_gateway_execution_role_without_the_redis_url_secret" {
  command = plan
  module { source = "./modules/iam" }

  variables {
    created_resources = merge(var.created_resources, { redis_url_secret_arn = null })
  }

  # The API execution role reads the same secret.
  expect_failures = [aws_iam_role.api_ecs_task_execution[0], aws_iam_role.gateway_task_execution[0]]
}

run "rejects_gateway_execution_role_without_a_license_secret" {
  command = plan
  module { source = "./modules/iam" }

  variables {
    created_resources = merge(var.created_resources, { brainstore_license_key_secret_arn = null })
  }

  # The API execution role reads the same secret.
  expect_failures = [aws_iam_role.api_ecs_task_execution[0], aws_iam_role.gateway_task_execution[0]]
}

run "rejects_waiter_role_without_the_deployment_log_group" {
  command = plan
  module { source = "./modules/iam" }

  variables {
    brainstore_deployment_log_group_arn = null
  }

  expect_failures = [aws_iam_role.brainstore_deployment_waiter[0]]
}

run "rejects_waiter_role_without_a_brainstore_fleet" {
  command = plan
  module { source = "./modules/iam" }

  variables {
    brainstore_asg_names = []
  }

  expect_failures = [aws_iam_role.brainstore_deployment_waiter[0]]
}
