resource "aws_iam_role" "api_ecs_task_execution" {
  count = var.create_iam && local.create_ecs_api ? 1 : 0

  name                 = local.role_names.api_ecs_task_execution
  assume_role_policy   = data.aws_iam_policy_document.ecs_task_assume_role.json
  permissions_boundary = var.permissions_boundary_arn
  tags = merge({
    Name = local.role_names.api_ecs_task_execution
  }, local.iam_tags)

  lifecycle {
    precondition {
      condition = alltrue([
        for arn in [
          local.kms_key_arn,
          var.created_resources.database_url_secret_arn,
          var.created_resources.function_tools_secret_arn,
          var.created_resources.redis_url_secret_arn,
          local.brainstore_license_key_secret_arn,
          var.internal_observability_enabled ? var.created_resources.internal_observability_api_key_secret_arn : "",
        ] : arn != null
      ])
      error_message = "The API ECS execution role needs the KMS key, database URL, function tools, Redis URL and Brainstore license secret ARNs, and the observability secret ARN when internal_observability_enabled is true. Pass them in created_resources, kms_key_arn or existing_brainstore_license_key_secret."
    }
  }
}

resource "aws_iam_role_policy_attachment" "api_ecs_task_execution_default" {
  count = var.create_iam && local.create_ecs_api ? 1 : 0

  role       = aws_iam_role.api_ecs_task_execution[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "api_ecs_task_execution_secrets" {
  count = var.create_iam && local.create_ecs_api ? 1 : 0

  name = "${var.deployment_name}-api-ecs-task-exec-secrets"
  role = aws_iam_role.api_ecs_task_execution[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
        ]
        Resource = concat(
          [
            var.created_resources.database_url_secret_arn,
            var.created_resources.function_tools_secret_arn,
            var.created_resources.redis_url_secret_arn,
          ],
          var.custom_ca_bundle_secret_arn == null ? [] : [var.custom_ca_bundle_secret_arn],
          var.internal_observability_enabled ? [var.created_resources.internal_observability_api_key_secret_arn] : [],
          [local.brainstore_license_key_secret_arn],
        )
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
        ]
        Resource = concat(
          [local.kms_key_arn],
          var.custom_ca_bundle_kms_key_arn == null ? [] : [var.custom_ca_bundle_kms_key_arn],
          local.brainstore_license_key_kms_key_arn == null ? [] : [local.brainstore_license_key_kms_key_arn],
        )
        Condition = {
          StringEquals = {
            "kms:ViaService" = "secretsmanager.${data.aws_region.current.region}.amazonaws.com"
          }
        }
      }
    ]
  })
}
