resource "aws_iam_role" "gateway_task_execution" {
  count = var.create_iam && local.create_ai_gateway ? 1 : 0

  name                 = local.role_names.gateway_task_execution
  path                 = local.role_paths.gateway_task_execution
  assume_role_policy   = data.aws_iam_policy_document.ecs_task_assume_role.json
  permissions_boundary = var.permissions_boundary_arn
  tags = merge({
    Name = local.role_names.gateway_task_execution
  }, local.iam_tags)

  lifecycle {
    precondition {
      condition = !local.is_managed_call || alltrue([
        for arn in [
          local.kms_key_arn,
          var.created_resources.redis_url_secret_arn,
          local.brainstore_license_key_secret_arn,
          var.internal_observability_enabled ? var.created_resources.internal_observability_api_key_secret_arn : "",
        ] : arn != null
      ])
      error_message = "The gateway execution role needs the KMS key, Redis URL and Brainstore license secret ARNs, and the observability secret ARN when internal_observability_enabled is true. Pass them in created_resources, kms_key_arn or existing_brainstore_license_key_secret."
    }
  }
}

resource "aws_iam_role_policy_attachment" "gateway_task_execution_default" {
  count = var.create_iam && local.create_ai_gateway ? 1 : 0

  role       = aws_iam_role.gateway_task_execution[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "gateway_task_execution_custom_ca_bundle_secret" {
  count = var.create_iam && local.create_ai_gateway && var.custom_ca_bundle_secret_arn != null ? 1 : 0

  name = "${var.deployment_name}-gateway-task-exec-custom-ca"
  role = aws_iam_role.gateway_task_execution[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [
        {
          Sid    = "AllowReadCustomCABundleSecret"
          Effect = "Allow"
          Action = [
            "secretsmanager:GetSecretValue",
          ]
          Resource = var.custom_ca_bundle_secret_arn
        }
      ],
      var.custom_ca_bundle_kms_key_arn == null ? [] : [
        {
          Sid    = "AllowKMSDecryptForSecretsManager"
          Effect = "Allow"
          Action = [
            "kms:Decrypt",
          ]
          Resource = var.custom_ca_bundle_kms_key_arn
          Condition = {
            StringEquals = {
              "kms:ViaService" = "secretsmanager.${data.aws_region.current.region}.amazonaws.com"
            }
          }
        }
      ],
    )
  })
}

resource "aws_iam_role_policy" "gateway_task_execution_secrets" {
  count = var.create_iam && local.create_ai_gateway ? 1 : 0

  name = "${var.deployment_name}-gateway-task-exec-secrets"
  role = aws_iam_role.gateway_task_execution[0].id

  # Keep the actions in step with local.customer_gateway_task_execution_secrets_policy in scopes.tf.

  policy = local.is_standalone_call ? local.customer_gateway_task_execution_secrets_policy : jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowReadSecrets"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
        ]
        Resource = compact([
          var.internal_observability_enabled ? var.created_resources.internal_observability_api_key_secret_arn : "",
          local.brainstore_license_key_secret_arn,
        ])
      },
      {
        Sid    = "AllowKMSDecryptForSecretsManager"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
        ]
        Resource = concat([local.kms_key_arn], local.brainstore_license_key_kms_key_arn == null ? [] : [local.brainstore_license_key_kms_key_arn])
        Condition = {
          StringEquals = {
            "kms:ViaService" = "secretsmanager.${data.aws_region.current.region}.amazonaws.com"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "gateway_task_execution_redis_secret" {
  count = var.create_iam && local.create_ai_gateway ? 1 : 0

  name = "${var.deployment_name}-gateway-task-exec-redis-secret"
  role = aws_iam_role.gateway_task_execution[0].id

  # Keep the actions in step with local.customer_gateway_task_execution_redis_secret_policy in scopes.tf.

  policy = local.is_standalone_call ? local.customer_gateway_task_execution_redis_secret_policy : jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowReadRedisURLSecret"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
        ]
        Resource = var.created_resources.redis_url_secret_arn
      },
      {
        Sid    = "AllowKMSDecryptForSecretsManager"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
        ]
        Resource = local.kms_key_arn
        Condition = {
          StringEquals = {
            "kms:ViaService" = "secretsmanager.${data.aws_region.current.region}.amazonaws.com"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role" "gateway_task" {
  count = var.create_iam && local.create_ai_gateway ? 1 : 0

  name                 = local.role_names.gateway_task
  path                 = local.role_paths.gateway_task
  assume_role_policy   = data.aws_iam_policy_document.ecs_task_assume_role.json
  permissions_boundary = var.permissions_boundary_arn
  tags = merge({
    Name = local.role_names.gateway_task
  }, local.iam_tags)
}

resource "aws_iam_role_policy" "gateway_task_customer_assume_role" {
  count = var.create_iam && local.create_ai_gateway ? 1 : 0

  name = "${var.deployment_name}-gateway-customer-assume-role"
  role = aws_iam_role.gateway_task[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "AllowAssumeBedrockRole"
        Effect   = "Allow"
        Action   = "sts:AssumeRole"
        Resource = length(var.ai_gateway_bedrock_assume_role_arns) > 0 ? var.ai_gateway_bedrock_assume_role_arns : ["*"]
        Condition = {
          StringLike = {
            "sts:ExternalId" = "bt:*"
          }
        }
      }
    ]
  })
}
