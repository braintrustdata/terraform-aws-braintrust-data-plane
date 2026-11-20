data "aws_iam_policy_document" "ecs_task_assume_role" {
  statement {
    sid     = "AllowECSTasksAssumeRole"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

# --- Task execution role (pulls secrets at container start) ---
resource "aws_iam_role" "task_execution" {
  name                 = "${var.deployment_name}-loop-runtime-task-exec"
  assume_role_policy   = data.aws_iam_policy_document.ecs_task_assume_role.json
  permissions_boundary = var.permissions_boundary_arn
  tags = merge({
    Name = "${var.deployment_name}-loop-runtime-task-exec"
  }, local.iam_tags)
}

resource "aws_iam_role_policy_attachment" "task_execution_default" {
  role       = aws_iam_role.task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "task_execution_secrets" {
  name = "${var.deployment_name}-loop-runtime-task-exec-secrets"
  role = aws_iam_role.task_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowReadSecrets"
        Effect = "Allow"
        Action = ["secretsmanager:GetSecretValue"]
        Resource = concat(
          [
            var.database_url_secret_arn,
            var.function_tools_secret_arn,
            var.redis_url_secret_arn,
          ],
          local.observability_enabled ? [var.internal_observability_api_key_secret_arn] : [],
          [var.brainstore_license_key_secret_arn],
        )
      },
      {
        Sid      = "AllowKMSDecryptForSecretsManager"
        Effect   = "Allow"
        Action   = ["kms:Decrypt"]
        Resource = concat([var.kms_key_arn], var.brainstore_license_key_kms_key_arn == null ? [] : [var.brainstore_license_key_kms_key_arn])
        Condition = {
          StringEquals = {
            "kms:ViaService" = "secretsmanager.${data.aws_region.current.region}.amazonaws.com"
          }
        }
      }
    ]
  })
}

# --- Dedicated task role (no secretsmanager access: no secrets in sandbox) ---
resource "aws_iam_role" "task" {
  name                 = "${var.deployment_name}-loop-runtime-task"
  assume_role_policy   = data.aws_iam_policy_document.ecs_task_assume_role.json
  permissions_boundary = var.permissions_boundary_arn
  tags = merge({
    Name = "${var.deployment_name}-loop-runtime-task"
  }, local.iam_tags)

  lifecycle {
    precondition {
      # Enforce the no-secrets-in-sandbox posture: the injected sandbox policy
      # must never grant Secrets Manager reads to the task role.
      condition     = !strcontains(lower(var.additional_task_role_policy_json), "secretsmanager")
      error_message = "additional_task_role_policy_json must not grant Secrets Manager access to the Loop runtime task role."
    }
  }
}

resource "aws_iam_role_policy" "brainstore_s3_access" {
  name = "LoopRuntimeBrainstoreS3Access"
  role = aws_iam_role.task.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [
        {
          Sid      = "AllowWriteBrainstoreWALObjects"
          Effect   = "Allow"
          Action   = ["s3:PutObject"]
          Resource = ["${var.brainstore_s3_bucket_arn}/brainstore/wal/object-store-objects/*"]
        },
        {
          Sid      = "AllowReadWriteBrainstoreRecentlyUpdated"
          Effect   = "Allow"
          Action   = ["s3:GetObject", "s3:PutObject"]
          Resource = ["${var.brainstore_s3_bucket_arn}/brainstore/wal/recently-updated/*"]
        },
        {
          Sid      = "AllowListBrainstoreRecentlyUpdated"
          Effect   = "Allow"
          Action   = ["s3:ListBucket"]
          Resource = [var.brainstore_s3_bucket_arn]
          Condition = {
            StringLike = { "s3:prefix" = ["brainstore/wal/recently-updated/*"] }
          }
        },
      ],
      [
        for stmt in [
          {
            Sid      = "AllowManageBrainstoreLocks"
            Effect   = "Allow"
            Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:DeleteObjectVersion"]
            Resource = ["${var.brainstore_s3_bucket_arn}/${local.locks_s3_path}/*"]
          },
          {
            Sid      = "AllowListBrainstoreLocks"
            Effect   = "Allow"
            Action   = ["s3:ListBucket"]
            Resource = [var.brainstore_s3_bucket_arn]
            Condition = {
              StringLike = { "s3:prefix" = ["${local.locks_s3_path}/*"] }
            }
          },
        ] : stmt if local.use_object_store_locks
      ],
    )
  })
}

resource "aws_iam_role_policy" "code_bundle_access" {
  name = "LoopRuntimeCodeBundleAccess"
  role = aws_iam_role.task.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "AllowReadWriteCodeBundleExo"
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject"]
        Resource = ["${var.code_bundle_bucket_arn}/exo/*"]
      },
      {
        Sid      = "AllowListCodeBundleExo"
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = [var.code_bundle_bucket_arn]
        Condition = {
          StringLike = { "s3:prefix" = ["exo", "exo/*"] }
        }
      }
    ]
  })
}

# The code-bundle bucket is encrypted with kms_key_arn. The Brainstore bucket
# is encrypted with kms_key_arn when module-owned, or with
# brainstore_s3_bucket_kms_key_arn when a caller provides an SSE-KMS bucket.
# SSE-KMS reads/writes need key access in addition to the S3 grants above.
resource "aws_iam_role_policy" "kms_access" {
  name = "LoopRuntimeKmsAccess"
  role = aws_iam_role.task.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "AllowKMSUseForS3"
      Effect = "Allow"
      Action = ["kms:Decrypt", "kms:GenerateDataKey", "kms:DescribeKey"]
      Resource = var.brainstore_s3_bucket_kms_key_arn != null ? [
        var.kms_key_arn,
        var.brainstore_s3_bucket_kms_key_arn,
      ] : [var.kms_key_arn]
      Condition = {
        StringEquals = {
          "kms:ViaService" = "s3.${data.aws_region.current.region}.amazonaws.com"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "cloudwatch_metrics_access" {
  name = "LoopRuntimeCloudWatchMetricsAccess"
  role = aws_iam_role.task.id
  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Sid = "AllowPutMetricData", Effect = "Allow", Action = "cloudwatch:PutMetricData", Resource = "*" }]
  })
}

resource "aws_iam_role_policy" "ec2_tags_read_access" {
  name = "LoopRuntimeEC2TagsReadAccess"
  role = aws_iam_role.task.id
  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Sid = "AllowDescribeEC2Tags", Effect = "Allow", Action = "ec2:DescribeTags", Resource = "*" }]
  })
}

resource "aws_iam_role_policy" "ecs_tags_read_access" {
  name = "LoopRuntimeECSResourceTagsReadAccess"
  role = aws_iam_role.task.id
  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Sid = "AllowListECSTags", Effect = "Allow", Action = "ecs:ListTagsForResource", Resource = "*" }]
  })
}

# ECS Exec needs SSM messages channels on the task role; only granted when Exec is enabled.
resource "aws_iam_role_policy" "execute_command" {
  count = var.enable_execute_command ? 1 : 0

  name = "LoopRuntimeExecuteCommand"
  role = aws_iam_role.task.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "AllowECSExec"
      Effect = "Allow"
      Action = [
        "ssmmessages:CreateControlChannel",
        "ssmmessages:CreateDataChannel",
        "ssmmessages:OpenControlChannel",
        "ssmmessages:OpenDataChannel",
      ]
      Resource = "*"
    }]
  })
}

# Sandbox-supplied IAM (MicroVM lifecycle, network connectors, optional PassRole).
resource "aws_iam_role_policy" "sandbox" {
  name   = "LoopRuntimeSandbox"
  role   = aws_iam_role.task.id
  policy = var.additional_task_role_policy_json
}
