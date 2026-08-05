locals {
  common_tags = merge({
    BraintrustDeploymentName = var.deployment_name
  }, var.custom_tags)

  container_name           = "loop-runtime"
  container_port           = 4001
  observability_enabled    = var.internal_observability_enabled
  loop_runtime_version_tag = element(reverse(split(":", var.container_image)), 0)
  brainstore_s3_bucket     = var.brainstore_s3_bucket_name
  use_object_store_locks   = var.brainstore_object_store_locks

  # Normalize like modules/brainstore-ec2 so Loop uses the deployment's shared
  # lock prefix (the writers must acquire locks from the same S3 namespace).
  locks_s3_path = trimprefix(var.brainstore_locks_s3_path, "/")

  # Match the API/Brainstore writers' WAL format so the shared realtime WAL stays
  # readable by every writer (same derivation as modules/api-ecs & modules/services).
  brainstore_wal_env = merge(
    var.brainstore_wal_footer_version != "" ? {
      BRAINSTORE_WAL_FOOTER_VERSION = var.brainstore_wal_footer_version
    } : {},
    var.skip_pg_for_brainstore_objects != "" ? {
      SKIP_PG_FOR_BRAINSTORE_OBJECTS = var.skip_pg_for_brainstore_objects
    } : {},
    (var.brainstore_wal_footer_version != "" || var.skip_pg_for_brainstore_objects != "") ? {
      BRAINSTORE_WAL_USE_EFFICIENT_FORMAT = "true"
    } : {},
  )

  # Plain (non-secret) environment. Secrets (DB/Redis/service-token URLs) are
  # injected via the container `secrets` block below. Sandbox-specific env comes
  # from var.sandbox_env_vars so this module stays sandbox-agnostic.
  core_env = merge(
    {
      BRAINTRUST_LEGACY_IDS              = "true"
      LOOP_RUNTIME_HOST                  = "0.0.0.0"
      LOOP_RUNTIME_PORT                  = tostring(local.container_port)
      LOOP_RUNTIME_LIFECYCLE_LOG         = var.loop_runtime_lifecycle_log
      LOOP_RUNTIME_REDIS_NAMESPACE       = "loop-runtime:${var.deployment_name}"
      LOOP_RUNTIME_STATE_DIR             = "/mnt/tmp/loop-runtime"
      ORG_NAME                           = var.org_name
      BRAINTRUST_API_URL                 = var.braintrust_api_url
      LOOP_RUNTIME_AI_PROXY_URL          = var.ai_proxy_url
      LOOP_RUNTIME_BRAINSTORE_READER_URL = var.brainstore_reader_url
      BRAINSTORE_VERBOSE                 = "1"
      BRAINSTORE_INDEX_URI               = "s3://${local.brainstore_s3_bucket}/brainstore/index"
      BRAINSTORE_REALTIME_WAL_URI        = "s3://${local.brainstore_s3_bucket}/brainstore/wal"
      BRAINSTORE_CODE_BUNDLE_URI         = "s3://${var.code_bundle_bucket}"
      BRAINSTORE_CACHE_DIR               = "/mnt/tmp/brainstore"
      BRAINSTORE_CONTROL_PLANE_TELEMETRY = var.monitoring_telemetry
      BRAINSTORE_DISABLE_STATUS_UPDATES  = var.brainstore_disable_status_updates
      NO_COLOR                           = "1"
      AWS_DEFAULT_REGION                 = data.aws_region.current.region
      AWS_REGION                         = data.aws_region.current.region
    },
    local.use_object_store_locks ? {
      BRAINSTORE_LOCKS_URI = "s3://${local.brainstore_s3_bucket}/${local.locks_s3_path}"
    } : {},
    local.brainstore_wal_env,
    trimspace(var.allowed_org_ids) != "" ? {
      ALLOWED_ORG_IDS = var.allowed_org_ids
    } : {},
    var.brainstore_license_key == null ? {} : {
      BRAINSTORE_LICENSE_KEY = var.brainstore_license_key
    },
    local.observability_enabled ? {
      BRAINSTORE_STATSD_ENDPOINT                   = "127.0.0.1:8125"
      BRAINSTORE_OTLP_HTTP_ENDPOINT                = "http://localhost:4318"
      BRAINSTORE_OTLP_TELEMETRY                    = "metrics,traces"
      BRAINSTORE_ENABLE_OTEL_ENV_RESOURCE_DETECTOR = "true"
      OTEL_RESOURCE_ATTRIBUTES                     = "deployment.environment.name=${var.internal_observability_env_name},env=${var.internal_observability_env_name}"
    } : {},
  )

  merged_env_vars = merge(local.core_env, var.sandbox_env_vars, var.extra_env_vars)

  container_secrets = concat(
    [
      { name = "BRAINSTORE_METADATA_URI", valueFrom = var.database_url_secret_arn },
      { name = "BRAINSTORE_WAL_URI", valueFrom = var.database_url_secret_arn },
      { name = "BRAINSTORE_XACT_MANAGER_URI", valueFrom = var.redis_url_secret_arn },
      { name = "BRAINSTORE_REDIS_URI", valueFrom = var.redis_url_secret_arn },
      { name = "SERVICE_TOKEN_SECRET_KEY", valueFrom = var.function_tools_secret_arn },
    ],
    local.use_object_store_locks ? [] : [
      { name = "BRAINSTORE_LOCKS_URI", valueFrom = var.redis_url_secret_arn },
    ],
  )

  app_log_configuration = jsondecode(local.observability_enabled ? jsonencode({
    logDriver = "awsfirelens"
    options = {
      Name           = "datadog"
      Host           = "http-intake.logs.${var.internal_observability_region}.datadoghq.com"
      TLS            = "on"
      provider       = "ecs"
      dd_service     = "loop-runtime"
      dd_source      = "rust"
      dd_message_key = "message"
      dd_tags        = "env:${var.internal_observability_env_name}"
      compress       = "gzip"
    }
    secretOptions = [
      { name = "apikey", valueFrom = var.internal_observability_api_key_secret_arn }
    ]
    }) : jsonencode({
    logDriver = "awslogs"
    options = {
      awslogs-group         = aws_cloudwatch_log_group.service.name
      awslogs-region        = data.aws_region.current.region
      awslogs-stream-prefix = "loop-runtime"
    }
  }))

  loop_runtime_container_definition = {
    name      = local.container_name
    image     = var.container_image
    essential = true
    user      = "1000:1000"
    linuxParameters = {
      initProcessEnabled = true
      capabilities = {
        drop = ["ALL"]
      }
    }
    portMappings = [
      {
        containerPort = local.container_port
        hostPort      = local.container_port
        protocol      = "tcp"
      }
    ]
    environment = [
      for key in sort(keys(local.merged_env_vars)) : {
        name  = key
        value = local.merged_env_vars[key]
      }
    ]
    secrets = local.container_secrets
    dependsOn = [
      for dep in [
        { containerName = "log-router", condition = "START" },
        { containerName = "datadog-agent", condition = "START" },
      ] : dep if local.observability_enabled
    ]
    healthCheck = {
      command     = ["CMD-SHELL", "curl -f http://localhost:${local.container_port}/health/liveness || exit 1"]
      interval    = 30
      retries     = 3
      startPeriod = 10
      timeout     = 5
    }
    logConfiguration = local.app_log_configuration
    mountPoints      = []
    systemControls   = []
    volumesFrom      = []
  }

  observability_sidecars = [
    for sidecar in [
      {
        name           = "log-router"
        essential      = true
        image          = "public.ecr.aws/aws-observability/aws-for-fluent-bit:stable"
        user           = "0"
        environment    = []
        mountPoints    = []
        portMappings   = []
        systemControls = []
        volumesFrom    = []
        firelensConfiguration = {
          type = "fluentbit"
          options = {
            enable-ecs-log-metadata = "true"
            config-file-type        = "file"
            config-file-value       = "/fluent-bit/configs/parse-json.conf"
          }
        }
        logConfiguration = {
          logDriver = "awslogs"
          options = {
            awslogs-group         = aws_cloudwatch_log_group.service.name
            awslogs-region        = data.aws_region.current.region
            awslogs-stream-prefix = "log-router"
          }
        }
        memoryReservation = 50
      },
      {
        name           = "datadog-agent"
        essential      = true
        image          = "public.ecr.aws/datadog/agent:7"
        mountPoints    = []
        portMappings   = []
        systemControls = []
        volumesFrom    = []
        logConfiguration = {
          logDriver = "awslogs"
          options = {
            awslogs-group         = aws_cloudwatch_log_group.service.name
            awslogs-region        = data.aws_region.current.region
            awslogs-stream-prefix = "datadog-agent"
          }
        }
        environment = [
          { name = "ECS_FARGATE", value = "true" },
          { name = "DD_SITE", value = "${var.internal_observability_region}.datadoghq.com" },
          { name = "DD_ENV", value = var.internal_observability_env_name },
          { name = "DD_SERVICE", value = "loop-runtime" },
          { name = "DD_VERSION", value = local.loop_runtime_version_tag },
          { name = "DD_PROCESS_AGENT_ENABLED", value = "true" },
          { name = "DD_OTLP_CONFIG_RECEIVER_PROTOCOLS_HTTP_ENDPOINT", value = "0.0.0.0:4318" },
        ]
        secrets = [
          { name = "DD_API_KEY", valueFrom = var.internal_observability_api_key_secret_arn }
        ]
        healthCheck = {
          command     = ["CMD-SHELL", "agent health"]
          interval    = 30
          retries     = 3
          startPeriod = 15
          timeout     = 5
        }
      }
    ] : sidecar if local.observability_enabled
  ]

  valid_fargate_memory_by_cpu = {
    "256"   = [512, 1024, 2048]
    "512"   = [1024, 2048, 3072, 4096]
    "1024"  = [2048, 3072, 4096, 5120, 6144, 7168, 8192]
    "2048"  = [for value in range(4096, 16385, 1024) : value]
    "4096"  = [for value in range(8192, 30721, 1024) : value]
    "8192"  = [for value in range(16384, 61441, 4096) : value]
    "16384" = [for value in range(32768, 122881, 8192) : value]
  }
}

data "aws_region" "current" {}

data "aws_iam_policy_document" "ecs_task_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_cloudwatch_log_group" "service" {
  name              = "/ecs/${var.deployment_name}/loop-runtime"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = merge({
    Name = "${var.deployment_name}-loop-runtime-logs"
  }, local.common_tags)
}

resource "aws_security_group" "task" {
  name        = "${var.deployment_name}-loop-runtime-task"
  description = "Security group for Loop runtime ECS tasks"
  vpc_id      = var.vpc_id
  tags = merge({
    Name = "${var.deployment_name}-loop-runtime-task"
  }, local.common_tags)
}

resource "aws_security_group_rule" "task_ingress_from_alb" {
  type                     = "ingress"
  from_port                = local.container_port
  to_port                  = local.container_port
  protocol                 = "tcp"
  source_security_group_id = var.alb_security_group_id
  description              = "Allow inbound traffic from Loop runtime ALB to tasks"
  security_group_id        = aws_security_group.task.id
}

resource "aws_security_group_rule" "task_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow all outbound traffic from Loop runtime ECS tasks"
  security_group_id = aws_security_group.task.id
}

# Allow the Loop runtime tasks to reach Postgres, Redis and Brainstore by adding
# ingress rules on those services' security groups.
resource "aws_vpc_security_group_ingress_rule" "postgres_from_task" {
  count = var.database_security_group_id == null ? 0 : 1

  from_port                    = var.database_port
  to_port                      = var.database_port
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.task.id
  description                  = "Allow inbound traffic from Loop runtime tasks."
  security_group_id            = var.database_security_group_id
  tags                         = local.common_tags
}

resource "aws_vpc_security_group_ingress_rule" "redis_from_task" {
  count = var.redis_security_group_id == null ? 0 : 1

  from_port                    = var.redis_port
  to_port                      = var.redis_port
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.task.id
  description                  = "Allow inbound traffic from Loop runtime tasks."
  security_group_id            = var.redis_security_group_id
  tags                         = local.common_tags
}

resource "aws_vpc_security_group_ingress_rule" "brainstore_from_task" {
  count = var.brainstore_security_group_id == null ? 0 : 1

  from_port                    = var.brainstore_port
  to_port                      = var.brainstore_port
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.task.id
  description                  = "Allow inbound traffic from Loop runtime tasks."
  security_group_id            = var.brainstore_security_group_id
  tags                         = local.common_tags
}

# --- Task execution role (pulls secrets at container start) ---
resource "aws_iam_role" "task_execution" {
  name                 = "${var.deployment_name}-loop-runtime-task-exec"
  assume_role_policy   = data.aws_iam_policy_document.ecs_task_assume_role.json
  permissions_boundary = var.permissions_boundary_arn
  tags = merge({
    Name = "${var.deployment_name}-loop-runtime-task-exec"
  }, local.common_tags)
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
        Effect = "Allow"
        Action = ["secretsmanager:GetSecretValue"]
        Resource = concat(
          [
            var.database_url_secret_arn,
            var.function_tools_secret_arn,
            var.redis_url_secret_arn,
          ],
          local.observability_enabled ? [var.internal_observability_api_key_secret_arn] : [],
        )
      },
      {
        Effect   = "Allow"
        Action   = ["kms:Decrypt"]
        Resource = var.kms_key_arn
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
  }, local.common_tags)

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
          Effect   = "Allow"
          Action   = ["s3:PutObject"]
          Resource = ["${var.brainstore_s3_bucket_arn}/brainstore/wal/object-store-objects/*"]
        },
        {
          Effect   = "Allow"
          Action   = ["s3:GetObject", "s3:PutObject"]
          Resource = ["${var.brainstore_s3_bucket_arn}/brainstore/wal/recently-updated/*"]
        },
        {
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
            Effect   = "Allow"
            Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
            Resource = ["${var.brainstore_s3_bucket_arn}/${local.locks_s3_path}/*"]
          },
          {
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
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject"]
        Resource = ["${var.code_bundle_bucket_arn}/exo/*"]
      },
      {
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

# The Brainstore and code-bundle buckets are encrypted with kms_key_arn, so
# SSE-KMS reads/writes need key access in addition to the S3 grants above.
resource "aws_iam_role_policy" "kms_access" {
  name = "LoopRuntimeKmsAccess"
  role = aws_iam_role.task.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["kms:Decrypt", "kms:GenerateDataKey", "kms:DescribeKey"]
      Resource = var.kms_key_arn
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
    Statement = [{ Effect = "Allow", Action = "cloudwatch:PutMetricData", Resource = "*" }]
  })
}

resource "aws_iam_role_policy" "ec2_tags_read_access" {
  name = "LoopRuntimeEC2TagsReadAccess"
  role = aws_iam_role.task.id
  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Action = "ec2:DescribeTags", Resource = "*" }]
  })
}

resource "aws_iam_role_policy" "ecs_tags_read_access" {
  name = "LoopRuntimeECSResourceTagsReadAccess"
  role = aws_iam_role.task.id
  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Action = "ecs:ListTagsForResource", Resource = "*" }]
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

resource "aws_ecs_task_definition" "loop_runtime" {
  family                   = "${var.deployment_name}-loop-runtime"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = tostring(var.cpu)
  memory                   = tostring(var.memory)
  execution_role_arn       = aws_iam_role.task_execution.arn
  task_role_arn            = aws_iam_role.task.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = var.cpu_architecture
  }

  dynamic "ephemeral_storage" {
    for_each = var.ephemeral_storage_gib == null ? [] : [var.ephemeral_storage_gib]
    content {
      size_in_gib = ephemeral_storage.value
    }
  }

  container_definitions = jsonencode(concat([local.loop_runtime_container_definition], local.observability_sidecars))

  tags = merge({
    Name = "${var.deployment_name}-loop-runtime"
  }, local.common_tags)

  lifecycle {
    precondition {
      condition     = contains(keys(local.valid_fargate_memory_by_cpu), tostring(var.cpu))
      error_message = "cpu must be a valid Fargate CPU value: 256, 512, 1024, 2048, 4096, 8192, or 16384."
    }
    precondition {
      condition     = contains(local.valid_fargate_memory_by_cpu[tostring(var.cpu)], var.memory)
      error_message = "memory must be a valid Fargate memory value for the configured cpu."
    }
  }
}

resource "terraform_data" "loop_runtime_http_listener" {
  input = var.loop_runtime_http_listener_arn
}

resource "aws_ecs_service" "loop_runtime" {
  name                              = "${var.deployment_name}-loop-runtime"
  cluster                           = var.ecs_cluster_arn
  task_definition                   = aws_ecs_task_definition.loop_runtime.arn
  desired_count                     = var.min_capacity
  launch_type                       = "FARGATE"
  enable_execute_command            = var.enable_execute_command
  health_check_grace_period_seconds = 60
  wait_for_steady_state             = true

  # Instant rollback on first deploy otherwise. Must be off (same as api-ecs/gateway-ecs).
  sigint_rollback = false

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.task.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = var.target_group_arn
    container_name   = local.container_name
    container_port   = local.container_port
  }

  depends_on = [terraform_data.loop_runtime_http_listener]

  lifecycle {
    ignore_changes = [desired_count]
  }

  tags = merge({
    Name = "${var.deployment_name}-loop-runtime"
  }, local.common_tags)
}
