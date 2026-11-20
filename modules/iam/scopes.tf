# Policy documents for a standalone run (iam_owner = "customer").
#
# Security runs this module before infrastructure creates the buckets, secrets,
# KMS key and Brainstore fleets, so these documents can't name exact ARNs. They
# grant the same actions as the managed documents, scoped by the deterministic
# prefixes that the modules in this repository use, the KMS alias and tags. Each
# resource below chooses between its managed document and its document here with
# local.is_standalone_call, so managed policies keep their exact ARNs.
#
# Only these ten policies have a twin, because only they name a module-created
# bucket, secret, KMS key or Brainstore fleet through created_resources or the
# waiter inputs. Every other policy names only deterministic names, tags or
# caller-supplied ARNs, so one document serves both calls. Each twin copies its
# managed document's actions, and each managed document carries a comment that
# points here. Keep them in step: iam_external_scopes.tftest.hcl asserts the
# action list of all ten in both calls.
#
# A statement that mixed module-created and caller-supplied resources is split in
# two. The module-created half carries the account or alias condition. The caller
# half names exact ARNs and no such condition, because the condition would block
# access to the caller's own resources. A caller-supplied resource wins over the
# module-created one it replaces, as in locals.tf.

# What the policies scope by, and the conditions that tie a pattern to this deployment.
locals {
  # Name prefixes come from modules/storage, modules/database, modules/elasticache,
  # modules/services-common, secrets.tf at the root, and modules/brainstore-ec2.
  scoped_bucket_arns = {
    brainstore       = "arn:${local.partition}:s3:::${var.deployment_name}-brainstore-*"
    code_bundle      = "arn:${local.partition}:s3:::${var.deployment_name}-code-bundles-*"
    lambda_responses = "arn:${local.partition}:s3:::${var.deployment_name}-lambda-responses-*"
  }

  secret_arn_prefix = "arn:${local.partition}:secretsmanager:${var.region}:${var.account_id}:secret:${var.deployment_name}"
  scoped_secret_arns = {
    database               = "${local.secret_arn_prefix}/DatabaseSecret-*"
    database_url           = "${local.secret_arn_prefix}/DatabaseUrl-*"
    database_url_override  = "${local.secret_arn_prefix}/DatabaseUrlOverride-*"
    function_tools         = "${local.secret_arn_prefix}/FunctionToolsSecret-*"
    redis_url              = "${local.secret_arn_prefix}/RedisUrl-*"
    brainstore_license_key = "${local.secret_arn_prefix}/brainstore/license-key-*"
    internal_observability = "${local.secret_arn_prefix}/internal-observability/api-key-*"
  }

  # The module's KMS key has an alias but a generated key ID, so the key is
  # scoped by alias. modules/kms creates alias/braintrust/<deployment_name>.
  module_kms_key_arn_pattern = "arn:${local.partition}:kms:${var.region}:${var.account_id}:key/*"

  autoscaling_group_arn_pattern = "arn:${local.partition}:autoscaling:${var.region}:${var.account_id}:autoScalingGroup:*:autoScalingGroupName/${var.deployment_name}-brainstore*"

  # A bucket pattern can match a bucket in another account, so every statement
  # on one names the deployment account. A KMS key pattern matches every key in
  # the account, so every statement on one needs the alias.
  bucket_account_condition = {
    StringEquals = { "s3:ResourceAccount" = var.account_id }
  }
  kms_alias_condition = {
    "ForAnyValue:StringEquals" = { "kms:ResourceAliases" = "alias/braintrust/${var.deployment_name}" }
  }
  kms_via_secrets_manager_condition = {
    StringEquals = { "kms:ViaService" = "secretsmanager.${var.region}.amazonaws.com" }
  }
  kms_via_s3_condition = {
    StringEquals = { "kms:ViaService" = "s3.${var.region}.amazonaws.com" }
  }

  s3_object_actions = [
    "s3:AbortMultipartUpload",
    "s3:Get*",
    "s3:PutObject*",
    "s3:List*",
    "s3:DeleteObject*",
  ]
  kms_data_actions = [
    "kms:Encrypt",
    "kms:Decrypt",
    "kms:ReEncrypt*",
    "kms:GenerateDataKey*",
    "kms:DescribeKey",
  ]
}

# Flags. Each is true when the module, not the caller, creates the resource.
locals {
  kms_key_is_module_created           = local.caller_kms_key_arn == null
  brainstore_bucket_is_module_created = var.existing_brainstore_s3_bucket_arn == null
  license_secret_is_module_created    = var.existing_brainstore_license_key_secret == null
  database_secret_is_module_created   = var.postgres_connection_override_credentials_secret_arn == null
}

# Module-created resources, as patterns. A list is empty when the caller supplies
# the resource instead.
locals {
  database_url_secret_arn_pattern   = var.use_postgres_connection_override ? local.scoped_secret_arns.database_url_override : local.scoped_secret_arns.database_url
  observability_secret_arn_patterns = var.internal_observability_enabled ? [local.scoped_secret_arns.internal_observability] : []
  license_secret_arn_patterns       = local.license_secret_is_module_created ? [local.scoped_secret_arns.brainstore_license_key] : []
  module_brainstore_bucket_arns     = local.brainstore_bucket_is_module_created ? [local.scoped_bucket_arns.brainstore, "${local.scoped_bucket_arns.brainstore}/*"] : []
  lambda_responses_bucket_arns      = [local.scoped_bucket_arns.lambda_responses, "${local.scoped_bucket_arns.lambda_responses}/*"]
  code_bundle_bucket_arns           = [local.scoped_bucket_arns.code_bundle, "${local.scoped_bucket_arns.code_bundle}/*"]

  # kms:Decrypt through Secrets Manager on the module-created key. Empty when the
  # caller supplies the key, which each policy then lists beside its other keys.
  module_key_decrypt_for_secrets = local.kms_key_is_module_created ? [{
    Sid       = "AllowKMSDecryptForSecretsManager"
    Effect    = "Allow"
    Action    = ["kms:Decrypt"]
    Resource  = [local.module_kms_key_arn_pattern]
    Condition = merge(local.kms_alias_condition, local.kms_via_secrets_manager_condition)
  }] : []

  # The module-created key for the data actions, split from the caller's keys the same way.
  module_key_data_access = local.kms_key_is_module_created ? [{
    Sid       = "AllowUseKMSKeys"
    Effect    = "Allow"
    Action    = local.kms_data_actions
    Resource  = [local.module_kms_key_arn_pattern]
    Condition = local.kms_alias_condition
  }] : []
}

# Caller-supplied resources, as exact ARNs with no scope condition. A list is
# empty when the module creates the resource instead.
locals {
  existing_license_secret_arns    = local.license_secret_is_module_created ? [] : [var.existing_brainstore_license_key_secret.arn]
  existing_brainstore_bucket_arns = local.brainstore_bucket_is_module_created ? [] : [var.existing_brainstore_s3_bucket_arn, "${var.existing_brainstore_s3_bucket_arn}/*"]
  existing_attachment_bucket_arns = var.existing_attachment_s3_bucket_arn == null || var.existing_attachment_s3_bucket_arn == "" ? [] : [var.existing_attachment_s3_bucket_arn, "${var.existing_attachment_s3_bucket_arn}/*"]

  # compact() drops the null and empty entries, so a caller input that is unset leaves no entry.
  caller_kms_key_arns                  = compact([local.caller_kms_key_arn])
  caller_kms_key_arns_with_bucket_keys = compact([local.caller_kms_key_arn, var.existing_brainstore_s3_bucket_kms_key_arn])

  # The caller-supplied lists that one policy joins, named so the policy reads as a sentence.
  api_ecs_caller_secret_arns     = compact(concat([var.custom_ca_bundle_secret_arn], local.existing_license_secret_arns))
  api_ecs_caller_kms_key_arns    = compact(concat(local.caller_kms_key_arns, [var.custom_ca_bundle_kms_key_arn, local.brainstore_license_key_kms_key_arn]))
  gateway_module_secret_arns     = concat(local.observability_secret_arn_patterns, local.license_secret_arn_patterns)
  gateway_caller_kms_key_arns    = compact(concat(local.caller_kms_key_arns, [local.brainstore_license_key_kms_key_arn]))
  api_handler_caller_bucket_arns = concat(local.existing_brainstore_bucket_arns, local.existing_attachment_bucket_arns)
}

# modules/iam/iam-api-ecs.tf: aws_iam_role_policy.api_ecs_task_execution_secrets
locals {
  customer_api_ecs_task_execution_secrets_policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [{
        Sid    = "AllowReadSecrets"
        Effect = "Allow"
        Action = ["secretsmanager:GetSecretValue"]
        Resource = concat(
          [local.database_url_secret_arn_pattern, local.scoped_secret_arns.function_tools, local.scoped_secret_arns.redis_url],
          local.observability_secret_arn_patterns,
          local.license_secret_arn_patterns,
        )
      }],
      length(local.api_ecs_caller_secret_arns) == 0 ? [] : [{
        Sid      = "AllowReadCallerSecrets"
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = local.api_ecs_caller_secret_arns
      }],
      local.module_key_decrypt_for_secrets,
      length(local.api_ecs_caller_kms_key_arns) == 0 ? [] : [{
        Sid       = "AllowKMSDecryptCallerKeysForSecretsManager"
        Effect    = "Allow"
        Action    = ["kms:Decrypt"]
        Resource  = local.api_ecs_caller_kms_key_arns
        Condition = local.kms_via_secrets_manager_condition
      }],
    )
  })
}

# modules/iam/iam-gateway.tf: aws_iam_role_policy.gateway_task_execution_secrets
locals {
  customer_gateway_task_execution_secrets_policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      length(local.gateway_module_secret_arns) == 0 ? [] : [{
        Sid      = "AllowReadSecrets"
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = local.gateway_module_secret_arns
      }],
      length(local.existing_license_secret_arns) == 0 ? [] : [{
        Sid      = "AllowReadCallerSecrets"
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = local.existing_license_secret_arns
      }],
      local.module_key_decrypt_for_secrets,
      length(local.gateway_caller_kms_key_arns) == 0 ? [] : [{
        Sid       = "AllowKMSDecryptCallerKeysForSecretsManager"
        Effect    = "Allow"
        Action    = ["kms:Decrypt"]
        Resource  = local.gateway_caller_kms_key_arns
        Condition = local.kms_via_secrets_manager_condition
      }],
    )
  })

  # aws_iam_role_policy.gateway_task_execution_redis_secret
  customer_gateway_task_execution_redis_secret_policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [{
        Sid      = "AllowReadRedisURLSecret"
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = local.scoped_secret_arns.redis_url
      }],
      local.module_key_decrypt_for_secrets,
      length(local.caller_kms_key_arns) == 0 ? [] : [{
        Sid       = "AllowKMSDecryptCallerKeysForSecretsManager"
        Effect    = "Allow"
        Action    = ["kms:Decrypt"]
        Resource  = local.caller_kms_key_arns
        Condition = local.kms_via_secrets_manager_condition
      }],
    )
  })
}

# modules/iam/iam-api-handler.tf: aws_iam_policy.api_handler
locals {
  customer_api_handler_policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [
        {
          Sid      = "AllowDescribeCacheClusters"
          Action   = ["elasticache:DescribeCacheClusters"]
          Effect   = "Allow"
          Resource = ["*"]
          Condition = {
            StringEquals = {
              "aws:ResourceTag/BraintrustDeploymentName" = var.deployment_name
            }
          }
        },
        {
          Sid       = "AllowReadWriteBuckets"
          Action    = local.s3_object_actions
          Effect    = "Allow"
          Resource  = concat(local.lambda_responses_bucket_arns, local.code_bundle_bucket_arns, local.module_brainstore_bucket_arns)
          Condition = local.bucket_account_condition
        },
      ],
      length(local.api_handler_caller_bucket_arns) == 0 ? [] : [{
        Sid      = "AllowReadWriteCallerBuckets"
        Action   = local.s3_object_actions
        Effect   = "Allow"
        Resource = local.api_handler_caller_bucket_arns
      }],
      local.module_key_data_access,
      length(local.caller_kms_key_arns_with_bucket_keys) == 0 ? [] : [{
        Sid      = "AllowUseCallerKMSKeys"
        Effect   = "Allow"
        Action   = local.kms_data_actions
        Resource = local.caller_kms_key_arns_with_bucket_keys
      }],
      [{
        Sid      = "AllowAssumeS3ExportRole"
        Action   = "sts:AssumeRole"
        Effect   = "Allow"
        Resource = length(var.s3_export_assume_role_arns) > 0 ? var.s3_export_assume_role_arns : ["*"]
        Condition = {
          StringLike = {
            "sts:ExternalId" = "bt:*"
          }
        }
      }],
      local.create_ecs_api ? [{
        Sid    = "AllowECSExec"
        Effect = "Allow"
        Action = [
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel",
        ]
        Resource = "*"
      }] : [],
      var.existing_attachment_s3_bucket_kms_key_arn != null && var.existing_attachment_s3_bucket_kms_key_arn != "" ? [{
        Sid      = "AllowUseAttachmentBucketKMSKey"
        Effect   = "Allow"
        Action   = local.kms_data_actions
        Resource = var.existing_attachment_s3_bucket_kms_key_arn
      }] : [],
    )
  })
}

# modules/iam/iam-brainstore.tf
locals {
  # aws_iam_role_policy.brainstore_s3_access
  customer_brainstore_s3_access_policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [{
        Sid       = "AllowReadWriteBuckets"
        Effect    = "Allow"
        Action    = local.s3_object_actions
        Resource  = concat(local.module_brainstore_bucket_arns, local.lambda_responses_bucket_arns)
        Condition = local.bucket_account_condition
      }],
      length(local.existing_brainstore_bucket_arns) == 0 ? [] : [{
        Sid      = "AllowReadWriteCallerBuckets"
        Effect   = "Allow"
        Action   = local.s3_object_actions
        Resource = local.existing_brainstore_bucket_arns
      }],
      [{
        Sid       = "AllowReadCodeBundles"
        Effect    = "Allow"
        Action    = ["s3:GetObject", "s3:ListBucket"]
        Resource  = local.code_bundle_bucket_arns
        Condition = local.bucket_account_condition
      }],
    )
  })

  # aws_iam_role_policy.brainstore_secrets_access. The license and custom CA entries exist only when Brainstore runs on EC2.
  brainstore_module_secret_arns = concat(
    local.database_secret_is_module_created ? [local.scoped_secret_arns.database] : [],
    [local.scoped_secret_arns.function_tools],
    local.create_brainstore_ec2 ? local.license_secret_arn_patterns : [],
    local.observability_secret_arn_patterns,
  )
  brainstore_caller_secret_arns = compact(concat(
    [var.postgres_connection_override_credentials_secret_arn],
    local.create_brainstore_ec2 ? concat(local.existing_license_secret_arns, [var.custom_ca_bundle_secret_arn]) : [],
  ))
  customer_brainstore_secrets_access_policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [{
        Sid      = "AllowReadSecrets"
        Effect   = "Allow"
        Action   = "secretsmanager:GetSecretValue"
        Resource = local.brainstore_module_secret_arns
      }],
      length(local.brainstore_caller_secret_arns) == 0 ? [] : [{
        Sid      = "AllowReadCallerSecrets"
        Effect   = "Allow"
        Action   = "secretsmanager:GetSecretValue"
        Resource = local.brainstore_caller_secret_arns
      }],
      local.brainstore_role_license_key_kms_key_arn == null ? [] : [{
        Sid       = "AllowKMSDecryptLicenseKeyForSecretsManager"
        Effect    = "Allow"
        Action    = "kms:Decrypt"
        Resource  = local.brainstore_role_license_key_kms_key_arn
        Condition = local.kms_via_secrets_manager_condition
      }],
      local.brainstore_role_custom_ca_bundle_kms_key == null ? [] : [{
        Sid       = "AllowKMSDecryptCustomCABundleKeyForSecretsManager"
        Effect    = "Allow"
        Action    = "kms:Decrypt"
        Resource  = local.brainstore_role_custom_ca_bundle_kms_key
        Condition = local.kms_via_secrets_manager_condition
      }],
    )
  })

  # aws_iam_role_policy.brainstore_kms_policy
  customer_brainstore_kms_policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      local.module_key_data_access,
      length(local.caller_kms_key_arns_with_bucket_keys) == 0 ? [] : [{
        Sid      = "AllowUseCallerKMSKeys"
        Effect   = "Allow"
        Action   = local.kms_data_actions
        Resource = local.caller_kms_key_arns_with_bucket_keys
      }],
    )
  })

  # aws_iam_role_policy.brainstore_redis_secret_access
  customer_brainstore_redis_secret_access_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "AllowReadRedisURLSecret"
      Effect   = "Allow"
      Action   = "secretsmanager:GetSecretValue"
      Resource = local.scoped_secret_arns.redis_url
    }]
  })
}

# modules/iam/iam-brainstore-deployment.tf: aws_iam_role_policy.brainstore_deployment_waiter.
# The waiter's log group is /braintrust/<deployment_name>/<deployment_name>-BrainstoreDeployment, which modules/brainstore-deployment creates.
locals {
  customer_brainstore_deployment_waiter_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowDescribeRolloutState"
        Effect = "Allow"
        Action = [
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:DescribeInstanceRefreshes",
          "ec2:DescribeInstances",
          "elasticloadbalancing:DescribeTargetHealth",
        ]
        Resource = "*"
      },
      {
        Sid      = "AllowStartInstanceRefresh"
        Effect   = "Allow"
        Action   = "autoscaling:StartInstanceRefresh"
        Resource = [local.autoscaling_group_arn_pattern]
        Condition = {
          StringEquals = { "autoscaling:ResourceTag/BraintrustDeploymentName" = var.deployment_name }
        }
      },
      {
        Sid      = "AllowWriteLogStreams"
        Effect   = "Allow"
        Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:${local.partition}:logs:${var.region}:${var.account_id}:log-group:/braintrust/${var.deployment_name}/${var.deployment_name}-BrainstoreDeployment:*"
      },
    ]
  })
}

# modules/iam/iam-lambda-functions.tf: aws_iam_role_policy.automation_cron_topic_map_report_read
locals {
  customer_automation_cron_topic_map_report_read_policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [{
        Sid       = "AllowReadTopicMapReports"
        Action    = ["s3:GetObject"]
        Effect    = "Allow"
        Resource  = "${local.scoped_bucket_arns.code_bundle}/bundles/topic_maps/*/*.report.json"
        Condition = local.bucket_account_condition
      }],
      # The code bundle bucket uses SSE-KMS with this key.
      local.kms_key_is_module_created ? [{
        Sid       = "AllowKMSDecryptTopicMapReports"
        Action    = ["kms:Decrypt"]
        Effect    = "Allow"
        Resource  = local.module_kms_key_arn_pattern
        Condition = merge(local.kms_alias_condition, local.kms_via_s3_condition)
      }] : [],
      local.kms_key_is_module_created ? [] : [{
        Sid       = "AllowKMSDecryptTopicMapReports"
        Action    = ["kms:Decrypt"]
        Effect    = "Allow"
        Resource  = local.caller_kms_key_arn
        Condition = local.kms_via_s3_condition
      }],
    )
  })
}
