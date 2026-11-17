# Plan-mode tests for the roles that modules/iam owns: database monitoring, the
# Brainstore deployment waiter, API ECS execution, the gateway roles, the shared
# API, quarantine and Brainstore roles.
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
  mock_data "aws_eks_cluster" {
    defaults = { identity = [{ oidc = [{ issuer = "https://oidc.eks.us-east-1.amazonaws.com/id/EXAMPLED539D4633E53DE1B71EXAMPLE" }] }] }
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
    database_secret_arn                       = "arn:aws:secretsmanager:us-east-1:123456789012:secret:bt-test/DatabaseSecret-AbCdEf"
    brainstore_s3_bucket_arn                  = "arn:aws:s3:::bt-test-brainstore-1"
    code_bundle_s3_bucket_arn                 = "arn:aws:s3:::bt-test-code-bundles-1"
    lambda_responses_s3_bucket_arn            = "arn:aws:s3:::bt-test-lambda-responses-1"
    quarantine_vpc_id                         = "vpc-87654321"
  }

  brainstore_deployment_log_group_arn = "arn:aws:logs:us-east-1:123456789012:log-group:/braintrust/bt-test/bt-test-BrainstoreDeployment"
  brainstore_asg_names                = ["bt-test-brainstore-reader-123", "bt-test-brainstore-writer-456"]
}

run "creates_every_role_with_its_released_name" {
  command = plan
  module { source = "./modules/iam" }

  variables {
    enable_quarantine_vpc = true
  }

  # Add each new role and policy to the lists below.
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
    condition = (
      aws_iam_role.api_handler[0].name == "bt-test-APIHandlerRole"
      && aws_iam_role.brainstore[0].name == "bt-test-brainstore-ec2-role"
      && aws_iam_role.quarantine_invoke[0].name == "bt-test-QuarantineInvokeRole"
      && aws_iam_role.quarantine_function[0].name == "bt-test-QuarantineFunctionRole"
    )
    error_message = "The shared API, Brainstore and quarantine roles must keep the physical name that existing stacks have."
  }

  assert {
    condition = (
      output.role_names == local.role_names
      && output.role_names.gateway_task == "bt-test-gateway-task"
      && output.role_names.api_handler == aws_iam_role.api_handler[0].name
      && output.role_names.brainstore == aws_iam_role.brainstore[0].name
    )
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

  assert {
    condition = (
      aws_iam_policy.api_handler[0].name == "bt-test-APIHandlerRolePolicy"
      && aws_iam_policy.api_handler_quarantine[0].name == "bt-test-APIHandlerQuarantinePolicy"
      && aws_iam_instance_profile.brainstore[0].name == "bt-test-brainstore-instance-profile"
      && aws_iam_role_policy.quarantine_invoke[0].name == "bt-test-QuarantineInvokeRolePolicy"
      && aws_iam_role_policy.brainstore_s3_access[0].name == "brainstore-s3-bucket"
      && aws_iam_role_policy.brainstore_secrets_access[0].name == "secrets-access"
      && aws_iam_role_policy.brainstore_kms_policy[0].name == "bt-test-brainstore-kms-policy"
      && aws_iam_role_policy.brainstore_redis_secret_access[0].name == "redis-secret-access"
    )
    error_message = "The shared API, quarantine and Brainstore policies and the instance profile must keep the name that existing stacks have."
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
    enable_quarantine_vpc    = true
  }

  # Add each new role to the lists below.
  assert {
    condition = alltrue([
      for role in [aws_iam_role.db_monitoring[0], aws_iam_role.brainstore_deployment_waiter[0], aws_iam_role.api_ecs_task_execution[0], aws_iam_role.gateway_task_execution[0], aws_iam_role.gateway_task[0]] :
      role.permissions_boundary == "arn:aws:iam::123456789012:policy/boundary"
    ])
    error_message = "Every role must carry the permissions boundary."
  }

  assert {
    condition = alltrue([
      for role in [
        aws_iam_role.api_handler[0], aws_iam_role.brainstore[0], aws_iam_role.quarantine_invoke[0], aws_iam_role.quarantine_function[0],
      ] : role.permissions_boundary == "arn:aws:iam::123456789012:policy/boundary"
    ])
    error_message = "The shared, quarantine and Brainstore roles must carry the permissions boundary too."
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

  # The services and services-common modules merged the caller's tags last. The
  # Brainstore EC2 module merged the deployment name last.
  assert {
    condition = (
      aws_iam_role.api_handler[0].tags.BraintrustDeploymentName == "caller"
      && aws_iam_role.brainstore[0].tags.BraintrustDeploymentName == "caller"
      && aws_iam_policy.api_handler[0].tags.BraintrustDeploymentName == "caller"
    )
    error_message = "The shared and Brainstore roles must keep the caller's deployment name tag, as before they moved."
  }

  assert {
    condition     = aws_iam_instance_profile.brainstore[0].tags.BraintrustDeploymentName == "bt-test" && aws_iam_instance_profile.brainstore[0].tags.team == "platform"
    error_message = "The Brainstore instance profile must keep the deployment name over the caller's tag."
  }

  assert {
    condition     = aws_iam_role.brainstore[0].tags.Name == "bt-test-brainstore-ec2-role"
    error_message = "The Brainstore role must keep its Name tag."
  }
}

run "creates_no_roles_when_create_iam_is_false" {
  command = plan
  module { source = "./modules/iam" }

  variables {
    create_iam = false
  }

  # Add each new resource to this list.
  assert {
    condition = (
      length(aws_iam_role.db_monitoring) == 0
      && length(aws_iam_role.brainstore_deployment_waiter) == 0
      && length(aws_iam_role.api_ecs_task_execution) == 0
      && length(aws_iam_role.gateway_task_execution) == 0
      && length(aws_iam_role.gateway_task) == 0
      && length(aws_iam_role_policy.gateway_task_customer_assume_role) == 0
      && length(aws_iam_role.api_handler) == 0
      && length(aws_iam_policy.api_handler) == 0
      && length(aws_iam_role_policy_attachment.api_handler_additional_policy) == 0
      && length(aws_iam_role.brainstore) == 0
      && length(aws_iam_role_policy.brainstore_s3_access) == 0
      && length(aws_iam_role_policy_attachment.brainstore_additional_policy) == 0
      && length(aws_iam_instance_profile.brainstore) == 0
      && length(aws_iam_role_policy.brainstore_redis_secret_access) == 0
      && length(aws_iam_role.quarantine_invoke) == 0
      && length(aws_iam_role.quarantine_function) == 0
    )
    error_message = "create_iam = false must create no roles or policies."
  }

  assert {
    condition     = output.role_names.db_monitoring == "bt-test-db-monitoring" && output.db_monitoring_role_arn == null && output.gateway_task_role_arn == null
    error_message = "Names must stay available when nothing is created, and ARNs must be null."
  }

  assert {
    condition     = output.role_names.api_handler == "bt-test-APIHandlerRole" && output.api_handler_role_arn == null && output.brainstore_instance_profile_arn == null
    error_message = "The shared and Brainstore role names must stay available, and their ARNs must be null."
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

run "external_eks_keeps_only_the_roles_that_helm_workloads_use" {
  command = plan
  module { source = "./modules/iam" }

  variables {
    use_deployment_mode_external_eks = true
    enable_quarantine_vpc            = true
  }

  assert {
    condition = (
      length(aws_iam_role.db_monitoring) == 1
      && length(aws_iam_role.api_handler) == 1
      && length(aws_iam_role.brainstore) == 1
      && length(aws_iam_role.quarantine_invoke) == 1
      && length(aws_iam_role.quarantine_function) == 1
      && length(aws_iam_role.brainstore_deployment_waiter) == 0
      && length(aws_iam_role.api_ecs_task_execution) == 0
      && length(aws_iam_role.gateway_task_execution) == 0
      && length(aws_iam_role.gateway_task) == 0
    )
    error_message = "External EKS has no waiter, API ECS service or gateway. It keeps database monitoring and the shared API, Brainstore and quarantine roles."
  }

  assert {
    condition = (
      length(aws_iam_instance_profile.brainstore) == 0
      && length(aws_iam_role_policy.brainstore_redis_secret_access) == 0
    )
    error_message = "External EKS has no Brainstore EC2 fleets, so it needs no instance profile or Redis policy."
  }

  assert {
    condition     = output.brainstore_instance_profile_arn == null
    error_message = "ARN outputs for roles that don't exist must be null."
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

  # The API execution role and the Brainstore Redis policy read the same secret.
  expect_failures = [aws_iam_role.api_ecs_task_execution[0], aws_iam_role.gateway_task_execution[0], aws_iam_role_policy.brainstore_redis_secret_access[0]]
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

run "api_role_trusts_lambda_and_ecs_tasks" {
  command = plan
  module { source = "./modules/iam" }

  assert {
    condition     = [for statement in jsondecode(aws_iam_role.api_handler[0].assume_role_policy).Statement : statement.Principal.Service] == ["lambda.amazonaws.com", "ecs-tasks.amazonaws.com"]
    error_message = "The shared API role must trust Lambda and ECS tasks, in that order."
  }

  assert {
    condition     = [for statement in jsondecode(aws_iam_role.brainstore[0].assume_role_policy).Statement : statement.Principal.Service] == ["ec2.amazonaws.com"]
    error_message = "The Brainstore role must trust EC2 only unless EKS trust is enabled."
  }
}

run "api_role_trusts_only_lambda_on_external_eks" {
  command = plan
  module { source = "./modules/iam" }

  variables {
    use_deployment_mode_external_eks = true
  }

  assert {
    condition     = [for statement in jsondecode(aws_iam_role.api_handler[0].assume_role_policy).Statement : statement.Principal.Service] == ["lambda.amazonaws.com"]
    error_message = "Without API ECS, the shared API role must not trust ECS tasks."
  }
}

run "api_and_brainstore_roles_trust_the_named_eks_cluster" {
  command = plan
  module { source = "./modules/iam" }

  variables {
    eks_cluster_arn         = "arn:aws:eks:us-east-1:123456789012:cluster/test"
    eks_namespace           = "braintrust"
    enable_eks_irsa         = true
    enable_eks_pod_identity = true
  }

  assert {
    condition = (
      one([for statement in jsondecode(aws_iam_role.api_handler[0].assume_role_policy).Statement : statement if try(statement.Action, null) == "sts:AssumeRoleWithWebIdentity"]).Principal.Federated == "arn:aws:iam::123456789012:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/EXAMPLED539D4633E53DE1B71EXAMPLE"
      && one([for statement in jsondecode(aws_iam_role.api_handler[0].assume_role_policy).Statement : statement if try(statement.Action, null) == "sts:AssumeRoleWithWebIdentity"]).Condition.StringLike["oidc.eks.us-east-1.amazonaws.com/id/EXAMPLED539D4633E53DE1B71EXAMPLE:sub"] == "system:serviceaccount:braintrust:*"
    )
    error_message = "The IRSA trust must name the cluster's OIDC provider and the namespace."
  }

  assert {
    condition = alltrue([
      for role in [aws_iam_role.api_handler[0], aws_iam_role.brainstore[0]] :
      one([for statement in jsondecode(role.assume_role_policy).Statement : statement if try(statement.Principal.Service, null) == "pods.eks.amazonaws.com"]).Condition.StringEquals == {
        "aws:RequestTag/eks-cluster-arn"      = ["arn:aws:eks:us-east-1:123456789012:cluster/test"]
        "aws:RequestTag/kubernetes-namespace" = ["braintrust"]
      }
    ])
    error_message = "The Pod Identity trust must be limited to the cluster and namespace."
  }

  assert {
    condition     = length(jsondecode(aws_iam_role.brainstore[0].assume_role_policy).Statement) == 3
    error_message = "The Brainstore role must trust EC2, the cluster's OIDC provider and Pod Identity."
  }
}

run "trust_overrides_replace_the_default_trust" {
  command = plan
  module { source = "./modules/iam" }

  variables {
    override_api_iam_role_trust_policy        = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    override_brainstore_iam_role_trust_policy = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Deny\",\"Principal\":\"*\",\"Action\":\"sts:AssumeRole\"}]}"
  }

  assert {
    condition     = aws_iam_role.api_handler[0].assume_role_policy == var.override_api_iam_role_trust_policy && aws_iam_role.brainstore[0].assume_role_policy == var.override_brainstore_iam_role_trust_policy
    error_message = "An override must replace the whole trust document."
  }
}

run "api_policy_grants_the_module_buckets_and_key_by_default" {
  command = plan
  module { source = "./modules/iam" }

  assert {
    condition = jsondecode(aws_iam_policy.api_handler[0].policy).Statement[1].Resource == [
      "arn:aws:s3:::bt-test-lambda-responses-1",
      "arn:aws:s3:::bt-test-lambda-responses-1/*",
      "arn:aws:s3:::bt-test-code-bundles-1",
      "arn:aws:s3:::bt-test-code-bundles-1/*",
      "arn:aws:s3:::bt-test-brainstore-1",
      "arn:aws:s3:::bt-test-brainstore-1/*",
    ]
    error_message = "The API role must reach the Lambda responses, code bundle and Brainstore buckets, in that order."
  }

  assert {
    condition     = jsondecode(aws_iam_policy.api_handler[0].policy).Statement[2].Resource == [var.created_resources.kms_key_arn]
    error_message = "Without a caller-provided bucket key, the API role must use the data plane key only."
  }

  assert {
    condition     = jsondecode(aws_iam_policy.api_handler[0].policy).Statement[3].Resource == ["*"] && length(jsondecode(aws_iam_policy.api_handler[0].policy).Statement) == 5
    error_message = "Without an export allowlist, the API role keeps the wildcard AssumeRole, and ECS Exec is the only optional statement."
  }
}

run "api_policy_names_the_caller_provided_buckets_and_keys" {
  command = plan
  module { source = "./modules/iam" }

  variables {
    existing_brainstore_s3_bucket_arn         = "arn:aws:s3:::existing-brainstore"
    existing_brainstore_s3_bucket_kms_key_arn = "arn:aws:kms:us-east-1:123456789012:key/55555555-5555-5555-5555-555555555555"
    existing_attachment_s3_bucket_arn         = "arn:aws:s3:::attachments"
    existing_attachment_s3_bucket_kms_key_arn = "arn:aws:kms:us-east-1:123456789012:key/44444444-4444-4444-4444-444444444444"
    s3_export_assume_role_arns                = ["arn:aws:iam::210987654321:role/export"]
    use_deployment_mode_external_eks          = true
  }

  assert {
    condition = jsondecode(aws_iam_policy.api_handler[0].policy).Statement[1].Resource == [
      "arn:aws:s3:::bt-test-lambda-responses-1",
      "arn:aws:s3:::bt-test-lambda-responses-1/*",
      "arn:aws:s3:::bt-test-code-bundles-1",
      "arn:aws:s3:::bt-test-code-bundles-1/*",
      "arn:aws:s3:::existing-brainstore",
      "arn:aws:s3:::existing-brainstore/*",
      "arn:aws:s3:::attachments",
      "arn:aws:s3:::attachments/*",
    ]
    error_message = "A caller-provided Brainstore bucket must replace the one the root module created, and the attachment bucket must follow."
  }

  assert {
    condition     = jsondecode(aws_iam_policy.api_handler[0].policy).Statement[2].Resource == [var.created_resources.kms_key_arn, "arn:aws:kms:us-east-1:123456789012:key/55555555-5555-5555-5555-555555555555"]
    error_message = "The API role must use the data plane key and the Brainstore bucket key."
  }

  assert {
    condition     = jsondecode(aws_iam_policy.api_handler[0].policy).Statement[3].Resource == ["arn:aws:iam::210987654321:role/export"]
    error_message = "An export allowlist must replace the wildcard AssumeRole."
  }

  assert {
    condition     = jsondecode(aws_iam_policy.api_handler[0].policy).Statement[4].Sid == "AttachmentBucketKMSAccess" && jsondecode(aws_iam_policy.api_handler[0].policy).Statement[4].Resource == "arn:aws:kms:us-east-1:123456789012:key/44444444-4444-4444-4444-444444444444"
    error_message = "A KMS-encrypted attachment bucket must grant its key, and without API ECS there is no ECS Exec statement before it."
  }
}

run "api_role_gets_additional_and_cloudwatch_policies" {
  command = plan
  module { source = "./modules/iam" }

  variables {
    service_additional_policy_arns = ["arn:aws:iam::123456789012:policy/a", "arn:aws:iam::123456789012:policy/b"]
  }

  assert {
    condition     = tolist([for attachment in aws_iam_role_policy_attachment.api_handler_additional_policy : attachment.policy_arn]) == var.service_additional_policy_arns
    error_message = "Each additional policy must be attached to the shared API role."
  }

  assert {
    condition     = jsondecode(aws_iam_role_policy.api_handler_cloudwatch_metrics[0].policy).Statement[0].Condition.StringEquals["cloudwatch:namespace"] == "Braintrust/Api"
    error_message = "API ECS autoscaling metrics must be limited to the Braintrust/Api namespace."
  }
}

run "brainstore_policies_use_the_bucket_the_caller_provides" {
  command = plan
  module { source = "./modules/iam" }

  variables {
    existing_brainstore_s3_bucket_arn         = "arn:aws:s3:::existing-brainstore"
    existing_brainstore_s3_bucket_kms_key_arn = "arn:aws:kms:us-east-1:123456789012:key/55555555-5555-5555-5555-555555555555"
  }

  assert {
    condition     = jsondecode(aws_iam_role_policy.brainstore_s3_access[0].policy).Statement[0].Resource == ["arn:aws:s3:::existing-brainstore", "arn:aws:s3:::existing-brainstore/*", "arn:aws:s3:::bt-test-lambda-responses-1", "arn:aws:s3:::bt-test-lambda-responses-1/*"]
    error_message = "Brainstore must read and write the caller's bucket and the Lambda responses bucket."
  }

  assert {
    condition     = jsondecode(aws_iam_role_policy.brainstore_s3_access[0].policy).Statement[1].Resource == ["arn:aws:s3:::bt-test-code-bundles-1", "arn:aws:s3:::bt-test-code-bundles-1/*"] && jsondecode(aws_iam_role_policy.brainstore_s3_access[0].policy).Statement[1].Action == ["s3:GetObject", "s3:ListBucket"]
    error_message = "Brainstore may only read the code bundle bucket."
  }

  assert {
    condition     = jsondecode(aws_iam_role_policy.brainstore_kms_policy[0].policy).Statement[0].Resource == [var.created_resources.kms_key_arn, "arn:aws:kms:us-east-1:123456789012:key/55555555-5555-5555-5555-555555555555"]
    error_message = "Brainstore must use the data plane key and the caller's bucket key."
  }
}

run "brainstore_secrets_policy_lists_every_secret_it_reads" {
  command = plan
  module { source = "./modules/iam" }

  variables {
    internal_observability_enabled = true
    custom_ca_bundle_secret_arn    = "arn:aws:secretsmanager:us-east-1:123456789012:secret:ca-bundle-AbCdEf"
    custom_ca_bundle_kms_key_arn   = "arn:aws:kms:us-east-1:123456789012:key/22222222-2222-2222-2222-222222222222"
    created_resources = merge(var.created_resources, {
      internal_observability_api_key_secret_arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:bt-test/internal-observability/api-key-AbCdEf"
    })
  }

  assert {
    condition = jsondecode(aws_iam_role_policy.brainstore_secrets_access[0].policy).Statement[0].Resource == [
      var.created_resources.database_secret_arn,
      var.created_resources.function_tools_secret_arn,
      var.created_resources.brainstore_license_key_secret_arn,
      "arn:aws:secretsmanager:us-east-1:123456789012:secret:bt-test/internal-observability/api-key-AbCdEf",
      "arn:aws:secretsmanager:us-east-1:123456789012:secret:ca-bundle-AbCdEf",
    ]
    error_message = "Brainstore must read the database, function tools, license, observability and CA bundle secrets, in that order."
  }

  assert {
    condition     = [for statement in jsondecode(aws_iam_role_policy.brainstore_secrets_access[0].policy).Statement : statement.Resource if statement.Action == "kms:Decrypt"] == ["arn:aws:kms:us-east-1:123456789012:key/22222222-2222-2222-2222-222222222222"]
    error_message = "Brainstore must decrypt with the CA bundle key, through Secrets Manager only."
  }
}

run "brainstore_optional_permissions_follow_their_inputs" {
  command = plan
  module { source = "./modules/iam" }

  variables {
    brainstore_enable_export          = true
    enable_brainstore_ec2_ssm         = true
    s3_export_assume_role_arns        = ["arn:aws:iam::210987654321:role/export"]
    brainstore_additional_policy_arns = ["arn:aws:iam::123456789012:policy/brainstore-extra"]
  }

  assert {
    condition     = jsondecode(aws_iam_role_policy.brainstore_export_assume_role[0].policy).Statement[0].Resource == ["arn:aws:iam::210987654321:role/export"]
    error_message = "Brainstore export must assume only the allowlisted roles."
  }

  assert {
    condition     = aws_iam_role_policy_attachment.brainstore_ssm[0].policy_arn == "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
    error_message = "SSM must attach the managed instance policy."
  }

  assert {
    condition     = tolist([for attachment in aws_iam_role_policy_attachment.brainstore_additional_policy : attachment.policy_arn]) == var.brainstore_additional_policy_arns
    error_message = "Each additional policy must be attached to the Brainstore role."
  }
}

run "brainstore_optional_permissions_are_absent_by_default" {
  command = plan
  module { source = "./modules/iam" }

  assert {
    condition = (
      length(aws_iam_role_policy.brainstore_export_assume_role) == 0
      && length(aws_iam_role_policy_attachment.brainstore_ssm) == 0
      && length(aws_iam_role_policy_attachment.brainstore_additional_policy) == 0
      && length(aws_iam_role_policy.api_handler_external_attachment_read) == 0
      && length(aws_iam_role_policy_attachment.api_handler_additional_policy) == 0
    )
    error_message = "Optional permissions must stay off unless their input is set."
  }
}

run "brainstore_reads_only_its_ssm_url_parameters_and_log_groups" {
  command = plan
  module { source = "./modules/iam" }

  assert {
    condition     = jsondecode(aws_iam_role_policy.brainstore_ssm_parameter_access[0].policy).Statement[0].Resource == ["arn:aws:ssm:us-east-1:123456789012:parameter/braintrust/bt-test/ai-proxy-url", "arn:aws:ssm:us-east-1:123456789012:parameter/braintrust/bt-test/ecs-api-url"]
    error_message = "Brainstore may read the AI proxy and ECS API URL parameters of this deployment."
  }

  assert {
    condition     = jsondecode(aws_iam_role_policy.brainstore_cloudwatch_logs_access[0].policy).Statement[0].Resource == ["arn:aws:logs:us-east-1:123456789012:log-group:/braintrust/bt-test/brainstore:*", "arn:aws:logs:us-east-1:123456789012:log-group:/braintrust/bt-test/brainstore/*:*"]
    error_message = "Brainstore may write only to its own log groups."
  }

  assert {
    condition     = jsondecode(aws_iam_role_policy.brainstore_redis_secret_access[0].policy).Statement[0].Resource == var.created_resources.redis_url_secret_arn
    error_message = "Brainstore may read only the Redis URL secret."
  }
}

run "external_eks_brainstore_reads_only_the_ai_proxy_url_parameter" {
  command = plan
  module { source = "./modules/iam" }

  variables {
    use_deployment_mode_external_eks = true
  }

  assert {
    condition     = jsondecode(aws_iam_role_policy.brainstore_ssm_parameter_access[0].policy).Statement[0].Resource == ["arn:aws:ssm:us-east-1:123456789012:parameter/braintrust/bt-test/ai-proxy-url"]
    error_message = "Without API ECS there is no ECS API URL parameter to read."
  }
}

run "brainstore_instance_profile_wraps_the_brainstore_role" {
  command = plan
  module { source = "./modules/iam" }

  assert {
    condition     = aws_iam_instance_profile.brainstore[0].role == aws_iam_role.brainstore[0].name
    error_message = "The instance profile must hold the Brainstore role."
  }
}

run "quarantine_roles_are_absent_without_a_quarantine_vpc" {
  command = plan
  module { source = "./modules/iam" }

  assert {
    condition = (
      length(aws_iam_role.quarantine_invoke) == 0
      && length(aws_iam_role.quarantine_function) == 0
      && length(aws_iam_policy.api_handler_quarantine) == 0
      && length(aws_iam_role_policy_attachment.api_handler_quarantine) == 0
      && output.quarantine_invoke_role_arn == null
      && output.quarantine_function_role_arn == null
    )
    error_message = "Quarantine IAM must share the quarantine gate."
  }
}

run "quarantine_policies_name_the_quarantine_vpc" {
  command = plan
  module { source = "./modules/iam" }

  variables {
    enable_quarantine_vpc = true
  }

  # The policy names the function role's ARN, which a plan can't know yet.
  override_resource {
    target          = aws_iam_role.quarantine_function[0]
    override_during = plan
    values          = { arn = "arn:aws:iam::123456789012:role/bt-test-QuarantineFunctionRole" }
  }

  assert {
    condition     = one([for statement in jsondecode(aws_iam_policy.api_handler_quarantine[0].policy).Statement : statement if try(statement.Sid, null) == "QuarantinePublish"]).Condition.StringEquals["lambda:VpcIds"] == "vpc-87654321"
    error_message = "The API role may publish quarantine functions only in the quarantine VPC."
  }

  assert {
    condition     = one([for statement in jsondecode(aws_iam_policy.api_handler_quarantine[0].policy).Statement : statement if try(statement.Action, null) == "iam:PassRole"]).Resource == "arn:aws:iam::123456789012:role/bt-test-QuarantineFunctionRole"
    error_message = "The API role may pass only the quarantine function role."
  }
}

run "rejects_shared_roles_without_the_kms_key" {
  command = plan
  module { source = "./modules/iam" }

  variables {
    created_resources = merge(var.created_resources, { kms_key_arn = null })
  }

  # Every role whose policies name the data plane key needs it.
  expect_failures = [aws_iam_role.api_handler[0], aws_iam_role.brainstore[0], aws_iam_role.api_ecs_task_execution[0], aws_iam_role.gateway_task_execution[0]]
}

run "rejects_the_brainstore_role_without_the_database_secret" {
  command = plan
  module { source = "./modules/iam" }

  variables {
    created_resources = merge(var.created_resources, { database_secret_arn = null })
  }

  expect_failures = [aws_iam_role.brainstore[0]]
}

run "rejects_the_quarantine_policies_without_the_quarantine_vpc" {
  command = plan
  module { source = "./modules/iam" }

  variables {
    enable_quarantine_vpc = true
    created_resources     = merge(var.created_resources, { quarantine_vpc_id = null })
  }

  expect_failures = [aws_iam_policy.api_handler_quarantine[0]]
}
