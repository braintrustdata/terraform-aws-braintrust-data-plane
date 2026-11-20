# The policy documents that modules/iam renders for a standalone run
# (iam_owner = "customer"). Security runs the module before infrastructure
# creates the buckets, secrets, KMS key and Brainstore fleets, so these documents
# scope module-created resources by prefix, KMS alias and tag, and keep exact ARNs
# for resources the caller supplies. A statement that mixed the two is split in
# two, so the account or alias condition can't block the caller's own resources.
#
# The mock provider returns one fixed document for every aws_iam_policy_document,
# but these policies are built with jsonencode, so the runs read the real content.
# The last run checks that the managed call keeps the exact ARNs.
#
# The condition keys come from the service authorization reference. s3:ResourceAccount
# applies to the bucket and object actions below, kms:ResourceAliases applies to
# every key action below, and autoscaling:ResourceTag/BraintrustDeploymentName
# applies to autoscaling:StartInstanceRefresh. A run can't prove AWS accepts them.

mock_provider "aws" {
  source = "./tests/mocks/aws"
  mock_data "aws_partition" {
    defaults = { partition = "aws" }
  }
}

variables {
  deployment_name = "bt-test"
  region          = "us-east-1"
  account_id      = "123456789012"
  iam_owner       = "customer"
}

run "scopes_standalone_policies_by_prefix_alias_and_tag" {
  command = plan
  module { source = "./modules/iam" }

  assert {
    condition = (
      [for s in jsondecode(aws_iam_policy.api_handler[0].policy).Statement : s if try(s.Sid, "") == "AllowReadWriteBuckets"][0].Resource == [
        "arn:aws:s3:::bt-test-lambda-responses-*", "arn:aws:s3:::bt-test-lambda-responses-*/*",
        "arn:aws:s3:::bt-test-code-bundles-*", "arn:aws:s3:::bt-test-code-bundles-*/*",
        "arn:aws:s3:::bt-test-brainstore-*", "arn:aws:s3:::bt-test-brainstore-*/*",
      ]
      && [for s in jsondecode(aws_iam_policy.api_handler[0].policy).Statement : s if try(s.Sid, "") == "AllowReadWriteBuckets"][0].Condition == { StringEquals = { "s3:ResourceAccount" = "123456789012" } }
    )
    error_message = "The shared API role must reach the module's three buckets by prefix, in the deployment account only."
  }

  assert {
    condition = (
      length([for s in jsondecode(aws_iam_policy.api_handler[0].policy).Statement : s if strcontains(jsonencode(try(s.Action, [])), "kms:Encrypt")]) == 1
      && [for s in jsondecode(aws_iam_policy.api_handler[0].policy).Statement : s if strcontains(jsonencode(try(s.Action, [])), "kms:Encrypt")][0].Resource == ["arn:aws:kms:us-east-1:123456789012:key/*"]
      && [for s in jsondecode(aws_iam_policy.api_handler[0].policy).Statement : s if strcontains(jsonencode(try(s.Action, [])), "kms:Encrypt")][0].Condition == {
        "ForAnyValue:StringEquals" = { "kms:ResourceAliases" = "alias/braintrust/bt-test" }
      }
    )
    error_message = "The shared API role must reach the module's KMS key through its alias."
  }

  assert {
    condition = (
      length(jsondecode(aws_iam_role_policy.brainstore_s3_access[0].policy).Statement) == 2
      && jsondecode(aws_iam_role_policy.brainstore_s3_access[0].policy).Statement[0].Resource == [
        "arn:aws:s3:::bt-test-brainstore-*", "arn:aws:s3:::bt-test-brainstore-*/*",
        "arn:aws:s3:::bt-test-lambda-responses-*", "arn:aws:s3:::bt-test-lambda-responses-*/*",
      ]
      && jsondecode(aws_iam_role_policy.brainstore_s3_access[0].policy).Statement[1].Resource == ["arn:aws:s3:::bt-test-code-bundles-*", "arn:aws:s3:::bt-test-code-bundles-*/*"]
      && alltrue([for s in jsondecode(aws_iam_role_policy.brainstore_s3_access[0].policy).Statement : s.Condition.StringEquals["s3:ResourceAccount"] == "123456789012"])
    )
    error_message = "The Brainstore role must reach the module's buckets by prefix, in the deployment account only."
  }

  assert {
    condition = (
      jsondecode(aws_iam_role_policy.brainstore_secrets_access[0].policy).Statement[0].Resource == [
        "arn:aws:secretsmanager:us-east-1:123456789012:secret:bt-test/DatabaseSecret-*",
        "arn:aws:secretsmanager:us-east-1:123456789012:secret:bt-test/FunctionToolsSecret-*",
        "arn:aws:secretsmanager:us-east-1:123456789012:secret:bt-test/brainstore/license-key-*",
      ]
      && jsondecode(aws_iam_role_policy.brainstore_redis_secret_access[0].policy).Statement[0].Resource == "arn:aws:secretsmanager:us-east-1:123456789012:secret:bt-test/RedisUrl-*"
      && length(jsondecode(aws_iam_role_policy.brainstore_secrets_access[0].policy).Statement) == 1
    )
    error_message = "The Brainstore role must reach the module's secrets by prefix, with no caller statement when the caller supplies none."
  }

  assert {
    condition = (
      jsondecode(aws_iam_role_policy.brainstore_kms_policy[0].policy).Statement == [{
        Sid       = "AllowUseKMSKeys"
        Effect    = "Allow"
        Action    = ["kms:Encrypt", "kms:Decrypt", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:DescribeKey"]
        Resource  = ["arn:aws:kms:us-east-1:123456789012:key/*"]
        Condition = { "ForAnyValue:StringEquals" = { "kms:ResourceAliases" = "alias/braintrust/bt-test" } }
      }]
    )
    error_message = "The Brainstore role must reach the module's KMS key through its alias and nothing else."
  }

  assert {
    condition = (
      jsondecode(aws_iam_role_policy.api_ecs_task_execution_secrets[0].policy).Statement == [
        {
          Sid    = "AllowReadSecrets"
          Effect = "Allow"
          Action = ["secretsmanager:GetSecretValue"]
          Resource = [
            "arn:aws:secretsmanager:us-east-1:123456789012:secret:bt-test/DatabaseUrl-*",
            "arn:aws:secretsmanager:us-east-1:123456789012:secret:bt-test/FunctionToolsSecret-*",
            "arn:aws:secretsmanager:us-east-1:123456789012:secret:bt-test/RedisUrl-*",
            "arn:aws:secretsmanager:us-east-1:123456789012:secret:bt-test/brainstore/license-key-*",
          ]
        },
        {
          Sid      = "AllowKMSDecryptForSecretsManager"
          Effect   = "Allow"
          Action   = ["kms:Decrypt"]
          Resource = ["arn:aws:kms:us-east-1:123456789012:key/*"]
          Condition = {
            "ForAnyValue:StringEquals" = { "kms:ResourceAliases" = "alias/braintrust/bt-test" }
            StringEquals               = { "kms:ViaService" = "secretsmanager.us-east-1.amazonaws.com" }
          }
        },
      ]
    )
    error_message = "The API ECS execution role must read the module's secrets by prefix and decrypt them through the key alias."
  }

  assert {
    condition = (
      jsondecode(aws_iam_role_policy.gateway_task_execution_secrets[0].policy).Statement[0].Resource == ["arn:aws:secretsmanager:us-east-1:123456789012:secret:bt-test/brainstore/license-key-*"]
      && jsondecode(aws_iam_role_policy.gateway_task_execution_redis_secret[0].policy).Statement[0].Resource == "arn:aws:secretsmanager:us-east-1:123456789012:secret:bt-test/RedisUrl-*"
      && jsondecode(aws_iam_role_policy.gateway_task_execution_redis_secret[0].policy).Statement[1].Resource == ["arn:aws:kms:us-east-1:123456789012:key/*"]
    )
    error_message = "The gateway execution role must read the module's secrets by prefix and decrypt them through the key alias."
  }

  assert {
    condition = (
      jsondecode(aws_iam_role_policy.automation_cron_topic_map_report_read[0].policy).Statement[0].Resource == "arn:aws:s3:::bt-test-code-bundles-*/bundles/topic_maps/*/*.report.json"
      && jsondecode(aws_iam_role_policy.automation_cron_topic_map_report_read[0].policy).Statement[0].Condition.StringEquals["s3:ResourceAccount"] == "123456789012"
      && jsondecode(aws_iam_role_policy.automation_cron_topic_map_report_read[0].policy).Statement[1].Resource == "arn:aws:kms:us-east-1:123456789012:key/*"
      && jsondecode(aws_iam_role_policy.automation_cron_topic_map_report_read[0].policy).Statement[1].Condition.StringEquals["kms:ViaService"] == "s3.us-east-1.amazonaws.com"
    )
    error_message = "AutomationCron's topic map read must name the code bundle prefix in the deployment account and the key alias."
  }

  assert {
    condition = (
      jsondecode(aws_iam_role_policy.brainstore_deployment_waiter[0].policy).Statement[1].Resource == ["arn:aws:autoscaling:us-east-1:123456789012:autoScalingGroup:*:autoScalingGroupName/bt-test-brainstore*"]
      && jsondecode(aws_iam_role_policy.brainstore_deployment_waiter[0].policy).Statement[1].Condition.StringEquals["autoscaling:ResourceTag/BraintrustDeploymentName"] == "bt-test"
      && jsondecode(aws_iam_role_policy.brainstore_deployment_waiter[0].policy).Statement[2].Resource == "arn:aws:logs:us-east-1:123456789012:log-group:/braintrust/bt-test/bt-test-BrainstoreDeployment:*"
    )
    error_message = "The waiter must refresh the Brainstore fleets by name prefix and tag, and write to its own log group by name."
  }

  # Each policy has a managed document and a standalone twin in scopes.tf. They must
  # grant the same actions, so this list is the same in both calls.
  assert {
    condition = alltrue([
      for pair in [
        [aws_iam_role_policy.api_ecs_task_execution_secrets[0].policy, ["secretsmanager:GetSecretValue", "kms:Decrypt"]],
        [aws_iam_role_policy.gateway_task_execution_secrets[0].policy, ["secretsmanager:GetSecretValue", "kms:Decrypt"]],
        [aws_iam_role_policy.gateway_task_execution_redis_secret[0].policy, ["secretsmanager:GetSecretValue", "kms:Decrypt"]],
        [aws_iam_policy.api_handler[0].policy, ["elasticache:DescribeCacheClusters", "s3:AbortMultipartUpload", "s3:Get*", "s3:PutObject*", "s3:List*", "s3:DeleteObject*", "kms:Encrypt", "kms:Decrypt", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:DescribeKey", "sts:AssumeRole", "ssmmessages:CreateControlChannel", "ssmmessages:CreateDataChannel", "ssmmessages:OpenControlChannel", "ssmmessages:OpenDataChannel"]],
        [aws_iam_role_policy.brainstore_s3_access[0].policy, ["s3:AbortMultipartUpload", "s3:Get*", "s3:PutObject*", "s3:List*", "s3:DeleteObject*", "s3:GetObject", "s3:ListBucket"]],
        [aws_iam_role_policy.brainstore_secrets_access[0].policy, ["secretsmanager:GetSecretValue"]],
        [aws_iam_role_policy.brainstore_kms_policy[0].policy, ["kms:Encrypt", "kms:Decrypt", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:DescribeKey"]],
        [aws_iam_role_policy.brainstore_redis_secret_access[0].policy, ["secretsmanager:GetSecretValue"]],
        [aws_iam_role_policy.brainstore_deployment_waiter[0].policy, ["autoscaling:DescribeAutoScalingGroups", "autoscaling:DescribeInstanceRefreshes", "ec2:DescribeInstances", "elasticloadbalancing:DescribeTargetHealth", "autoscaling:StartInstanceRefresh", "logs:CreateLogStream", "logs:PutLogEvents"]],
        [aws_iam_role_policy.automation_cron_topic_map_report_read[0].policy, ["s3:GetObject", "kms:Decrypt"]],
      ] : toset(flatten([for s in jsondecode(pair[0]).Statement : try(tolist(s.Action), [s.Action])])) == toset(pair[1])
    ])
    error_message = "A standalone policy must grant the same actions as its managed twin."
  }
}

run "splits_statements_that_mix_module_created_and_caller_supplied_resources" {
  command = plan
  module { source = "./modules/iam" }

  variables {
    custom_ca_bundle_secret_arn               = "arn:aws:secretsmanager:us-east-1:123456789012:secret:custom-ca-AbCdEf"
    custom_ca_bundle_kms_key_arn              = "arn:aws:kms:us-east-1:123456789012:key/22222222-2222-2222-2222-222222222222"
    existing_brainstore_license_key_secret    = { arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:license-AbCdEf", kms_key_arn = "arn:aws:kms:us-east-1:123456789012:key/33333333-3333-3333-3333-333333333333" }
    existing_brainstore_s3_bucket_arn         = "arn:aws:s3:::existing-brainstore"
    existing_brainstore_s3_bucket_kms_key_arn = "arn:aws:kms:us-east-1:123456789012:key/44444444-4444-4444-4444-444444444444"
    existing_attachment_s3_bucket_arn         = "arn:aws:s3:::existing-attachments"
  }

  # API ECS execution: the module's secrets and key, then the caller's.
  assert {
    condition = (
      length(jsondecode(aws_iam_role_policy.api_ecs_task_execution_secrets[0].policy).Statement) == 4
      && jsondecode(aws_iam_role_policy.api_ecs_task_execution_secrets[0].policy).Statement[0].Resource == [
        "arn:aws:secretsmanager:us-east-1:123456789012:secret:bt-test/DatabaseUrl-*",
        "arn:aws:secretsmanager:us-east-1:123456789012:secret:bt-test/FunctionToolsSecret-*",
        "arn:aws:secretsmanager:us-east-1:123456789012:secret:bt-test/RedisUrl-*",
      ]
      && jsondecode(aws_iam_role_policy.api_ecs_task_execution_secrets[0].policy).Statement[1].Resource == [
        "arn:aws:secretsmanager:us-east-1:123456789012:secret:custom-ca-AbCdEf",
        "arn:aws:secretsmanager:us-east-1:123456789012:secret:license-AbCdEf",
      ]
      && contains(keys(jsondecode(aws_iam_role_policy.api_ecs_task_execution_secrets[0].policy).Statement[2].Condition), "ForAnyValue:StringEquals")
      && jsondecode(aws_iam_role_policy.api_ecs_task_execution_secrets[0].policy).Statement[3].Resource == [
        "arn:aws:kms:us-east-1:123456789012:key/22222222-2222-2222-2222-222222222222",
        "arn:aws:kms:us-east-1:123456789012:key/33333333-3333-3333-3333-333333333333",
      ]
      && !contains(keys(jsondecode(aws_iam_role_policy.api_ecs_task_execution_secrets[0].policy).Statement[3].Condition), "ForAnyValue:StringEquals")
    )
    error_message = "API ECS execution must split the module's secrets and key from the custom CA and license secrets and keys, with no alias condition on the caller's keys."
  }

  # Shared API role: the module's buckets and key, then the caller's.
  assert {
    condition = (
      [for s in jsondecode(aws_iam_policy.api_handler[0].policy).Statement : s if try(s.Sid, "") == "AllowReadWriteBuckets"][0].Resource == [
        "arn:aws:s3:::bt-test-lambda-responses-*", "arn:aws:s3:::bt-test-lambda-responses-*/*",
        "arn:aws:s3:::bt-test-code-bundles-*", "arn:aws:s3:::bt-test-code-bundles-*/*",
      ]
      && [for s in jsondecode(aws_iam_policy.api_handler[0].policy).Statement : s if try(s.Sid, "") == "AllowReadWriteCallerBuckets"][0].Resource == [
        "arn:aws:s3:::existing-brainstore", "arn:aws:s3:::existing-brainstore/*",
        "arn:aws:s3:::existing-attachments", "arn:aws:s3:::existing-attachments/*",
      ]
      && !contains(keys([for s in jsondecode(aws_iam_policy.api_handler[0].policy).Statement : s if try(s.Sid, "") == "AllowReadWriteCallerBuckets"][0]), "Condition")
      && [for s in jsondecode(aws_iam_policy.api_handler[0].policy).Statement : s if try(s.Sid, "") == "AllowUseCallerKMSKeys"][0].Resource == ["arn:aws:kms:us-east-1:123456789012:key/44444444-4444-4444-4444-444444444444"]
    )
    error_message = "The shared API role must keep exact ARNs, with no account condition, for an existing Brainstore bucket, an attachment bucket and the bucket's key."
  }

  # Brainstore: no module-created Brainstore bucket, and the license secret is the caller's.
  assert {
    condition = (
      jsondecode(aws_iam_role_policy.brainstore_s3_access[0].policy).Statement[0].Resource == ["arn:aws:s3:::bt-test-lambda-responses-*", "arn:aws:s3:::bt-test-lambda-responses-*/*"]
      && jsondecode(aws_iam_role_policy.brainstore_s3_access[0].policy).Statement[1].Resource == ["arn:aws:s3:::existing-brainstore", "arn:aws:s3:::existing-brainstore/*"]
      && !contains(keys(jsondecode(aws_iam_role_policy.brainstore_s3_access[0].policy).Statement[1]), "Condition")
      && jsondecode(aws_iam_role_policy.brainstore_secrets_access[0].policy).Statement[0].Resource == [
        "arn:aws:secretsmanager:us-east-1:123456789012:secret:bt-test/DatabaseSecret-*",
        "arn:aws:secretsmanager:us-east-1:123456789012:secret:bt-test/FunctionToolsSecret-*",
      ]
      && jsondecode(aws_iam_role_policy.brainstore_secrets_access[0].policy).Statement[1].Resource == [
        "arn:aws:secretsmanager:us-east-1:123456789012:secret:license-AbCdEf",
        "arn:aws:secretsmanager:us-east-1:123456789012:secret:custom-ca-AbCdEf",
      ]
      && length(jsondecode(aws_iam_role_policy.brainstore_kms_policy[0].policy).Statement) == 2
      && jsondecode(aws_iam_role_policy.brainstore_kms_policy[0].policy).Statement[1].Resource == ["arn:aws:kms:us-east-1:123456789012:key/44444444-4444-4444-4444-444444444444"]
    )
    error_message = "The Brainstore role must split an existing Brainstore bucket, license secret and bucket key from the module's resources."
  }

  # Gateway execution: only the license secret is the caller's.
  assert {
    condition = (
      length(jsondecode(aws_iam_role_policy.gateway_task_execution_secrets[0].policy).Statement) == 3
      && jsondecode(aws_iam_role_policy.gateway_task_execution_secrets[0].policy).Statement[0].Resource == ["arn:aws:secretsmanager:us-east-1:123456789012:secret:license-AbCdEf"]
      && jsondecode(aws_iam_role_policy.gateway_task_execution_secrets[0].policy).Statement[2].Resource == ["arn:aws:kms:us-east-1:123456789012:key/33333333-3333-3333-3333-333333333333"]
    )
    error_message = "The gateway execution role must read a caller's license secret and key by exact ARN, beside the module's key alias."
  }
}

run "uses_exact_caller_key_without_alias_condition_when_the_caller_supplies_the_kms_key" {
  command = plan
  module { source = "./modules/iam" }

  variables {
    kms_key_arn = "arn:aws:kms:us-east-1:123456789012:key/55555555-5555-5555-5555-555555555555"
  }

  assert {
    condition = (
      jsondecode(aws_iam_role_policy.brainstore_kms_policy[0].policy).Statement == [{
        Sid      = "AllowUseCallerKMSKeys"
        Effect   = "Allow"
        Action   = ["kms:Encrypt", "kms:Decrypt", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:DescribeKey"]
        Resource = ["arn:aws:kms:us-east-1:123456789012:key/55555555-5555-5555-5555-555555555555"]
      }]
      && jsondecode(aws_iam_role_policy.automation_cron_topic_map_report_read[0].policy).Statement[1].Resource == "arn:aws:kms:us-east-1:123456789012:key/55555555-5555-5555-5555-555555555555"
      && !contains(keys(jsondecode(aws_iam_role_policy.automation_cron_topic_map_report_read[0].policy).Statement[1].Condition), "ForAnyValue:StringEquals")
      && length(jsondecode(aws_iam_role_policy.gateway_task_execution_redis_secret[0].policy).Statement) == 2
      && jsondecode(aws_iam_role_policy.gateway_task_execution_redis_secret[0].policy).Statement[1].Resource == ["arn:aws:kms:us-east-1:123456789012:key/55555555-5555-5555-5555-555555555555"]
    )
    error_message = "A caller-supplied KMS key must keep its exact ARN and carry no alias condition."
  }
}

run "scopes_the_postgres_override_secrets_in_the_standalone_call" {
  command = plan
  module { source = "./modules/iam" }

  variables {
    use_postgres_connection_override                    = true
    postgres_connection_override_credentials_secret_arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:app-db-credentials-AbCdEf"
    internal_observability_enabled                      = true
  }

  assert {
    condition = (
      contains(jsondecode(aws_iam_role_policy.api_ecs_task_execution_secrets[0].policy).Statement[0].Resource, "arn:aws:secretsmanager:us-east-1:123456789012:secret:bt-test/DatabaseUrlOverride-*")
      && !contains(jsondecode(aws_iam_role_policy.api_ecs_task_execution_secrets[0].policy).Statement[0].Resource, "arn:aws:secretsmanager:us-east-1:123456789012:secret:bt-test/DatabaseUrl-*")
      && contains(jsondecode(aws_iam_role_policy.api_ecs_task_execution_secrets[0].policy).Statement[0].Resource, "arn:aws:secretsmanager:us-east-1:123456789012:secret:bt-test/internal-observability/api-key-*")
    )
    error_message = "API ECS execution must read the override's URL secret, not the module's database URL secret."
  }

  assert {
    condition = (
      jsondecode(aws_iam_role_policy.brainstore_secrets_access[0].policy).Statement[0].Resource == [
        "arn:aws:secretsmanager:us-east-1:123456789012:secret:bt-test/FunctionToolsSecret-*",
        "arn:aws:secretsmanager:us-east-1:123456789012:secret:bt-test/brainstore/license-key-*",
        "arn:aws:secretsmanager:us-east-1:123456789012:secret:bt-test/internal-observability/api-key-*",
      ]
      && jsondecode(aws_iam_role_policy.brainstore_secrets_access[0].policy).Statement[1].Resource == ["arn:aws:secretsmanager:us-east-1:123456789012:secret:app-db-credentials-AbCdEf"]
    )
    error_message = "Brainstore must read the override's credentials secret by exact ARN, and not the module's database secret."
  }
}

run "keeps_exact_arns_in_the_managed_call" {
  command = plan
  module { source = "./modules/iam" }

  variables {
    iam_owner = "braintrust"
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
    condition = (
      !strcontains(aws_iam_policy.api_handler[0].policy, "ResourceAccount")
      && !strcontains(aws_iam_policy.api_handler[0].policy, "ResourceAliases")
      && strcontains(aws_iam_policy.api_handler[0].policy, "arn:aws:s3:::bt-test-code-bundles-1/*")
      && strcontains(aws_iam_role_policy.brainstore_secrets_access[0].policy, "bt-test/DatabaseSecret-AbCdEf")
      && strcontains(aws_iam_role_policy.brainstore_deployment_waiter[0].policy, "autoScalingGroupName/bt-test-brainstore-reader-123")
      && !strcontains(aws_iam_role_policy.api_ecs_task_execution_secrets[0].policy, "ResourceAliases")
    )
    error_message = "A managed policy must keep its exact ARNs and carry no alias or account scope."
  }
  # Each policy has a managed document and a standalone twin in scopes.tf. They must
  # grant the same actions, so this list is the same in both calls.
  assert {
    condition = alltrue([
      for pair in [
        [aws_iam_role_policy.api_ecs_task_execution_secrets[0].policy, ["secretsmanager:GetSecretValue", "kms:Decrypt"]],
        [aws_iam_role_policy.gateway_task_execution_secrets[0].policy, ["secretsmanager:GetSecretValue", "kms:Decrypt"]],
        [aws_iam_role_policy.gateway_task_execution_redis_secret[0].policy, ["secretsmanager:GetSecretValue", "kms:Decrypt"]],
        [aws_iam_policy.api_handler[0].policy, ["elasticache:DescribeCacheClusters", "s3:AbortMultipartUpload", "s3:Get*", "s3:PutObject*", "s3:List*", "s3:DeleteObject*", "kms:Encrypt", "kms:Decrypt", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:DescribeKey", "sts:AssumeRole", "ssmmessages:CreateControlChannel", "ssmmessages:CreateDataChannel", "ssmmessages:OpenControlChannel", "ssmmessages:OpenDataChannel"]],
        [aws_iam_role_policy.brainstore_s3_access[0].policy, ["s3:AbortMultipartUpload", "s3:Get*", "s3:PutObject*", "s3:List*", "s3:DeleteObject*", "s3:GetObject", "s3:ListBucket"]],
        [aws_iam_role_policy.brainstore_secrets_access[0].policy, ["secretsmanager:GetSecretValue"]],
        [aws_iam_role_policy.brainstore_kms_policy[0].policy, ["kms:Encrypt", "kms:Decrypt", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:DescribeKey"]],
        [aws_iam_role_policy.brainstore_redis_secret_access[0].policy, ["secretsmanager:GetSecretValue"]],
        [aws_iam_role_policy.brainstore_deployment_waiter[0].policy, ["autoscaling:DescribeAutoScalingGroups", "autoscaling:DescribeInstanceRefreshes", "ec2:DescribeInstances", "elasticloadbalancing:DescribeTargetHealth", "autoscaling:StartInstanceRefresh", "logs:CreateLogStream", "logs:PutLogEvents"]],
        [aws_iam_role_policy.automation_cron_topic_map_report_read[0].policy, ["s3:GetObject", "kms:Decrypt"]],
      ] : toset(flatten([for s in jsondecode(pair[0]).Statement : try(tolist(s.Action), [s.Action])])) == toset(pair[1])
    ])
    error_message = "A managed policy must grant the same actions as its standalone twin."
  }
}
