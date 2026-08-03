locals {
  common_tags = merge({
    BraintrustDeploymentName = var.deployment_name
  }, var.custom_tags)

  container_name        = "gateway"
  container_port        = 8080
  observability_enabled = var.internal_observability_enabled
  # Pin the secret version in valueFrom so rotating the key revises the task definition and rolls the service.
  # Format: arn:...:secret:name:json-key:version-stage:version-id
  # Empty json-key = full secret string; empty stage pins by version-id only.
  observability_api_key_value_from = "${var.internal_observability_api_key_secret_arn}:::${var.internal_observability_api_key_secret_version}"
  gateway_version_tag              = element(reverse(split(":", var.container_image)), 0)
  unsafe_url_request_mode          = var.unsafe_url_request_mode == null ? "" : trimspace(var.unsafe_url_request_mode)
  url_security_dns_servers         = var.url_security_dns_servers == null ? "" : trimspace(var.url_security_dns_servers)
  url_security_allow_cidrs         = var.url_security_allow_cidrs == null ? "" : trimspace(var.url_security_allow_cidrs)
  url_security_env_vars = merge(
    local.unsafe_url_request_mode != "" ? {
      BRAINTRUST_UNSAFE_URL_REQUEST_MODE = local.unsafe_url_request_mode
    } : {},
    local.url_security_dns_servers != "" ? {
      BRAINTRUST_URL_SECURITY_DNS_SERVERS = local.url_security_dns_servers
    } : {},
    local.url_security_allow_cidrs != "" ? {
      BRAINTRUST_URL_SECURITY_ALLOW_CIDRS = local.url_security_allow_cidrs
    } : {}
  )
  redis_scheme = var.use_redis_replication_group ? "rediss" : "redis"
  base_env_vars = merge({
    GATEWAY_ENV        = "production"
    GATEWAY_REGION     = data.aws_region.current.region
    BRAINTRUST_APP_URL = var.braintrust_app_url
    BRAINTRUST_API_URL = var.braintrust_api_url

    COMPLETIONS_CACHE_REDIS_URL = "${local.redis_scheme}://${var.redis_host}:${var.redis_port}"
    AUTH_CACHE_REDIS_URL        = "${local.redis_scheme}://${var.redis_host}:${var.redis_port}"
    GATEWAY_JSON_LOGS           = "true"
    OTLP_HTTP_ENDPOINT          = local.observability_enabled ? "http://localhost:4318" : "https://www.braintrust.dev/api/pulse/otel"
    },
    local.url_security_env_vars,
    local.observability_enabled ? {
      DD_ENV     = var.internal_observability_env_name
      DD_VERSION = local.gateway_version_tag
    } : {},
    local.observability_enabled && trimspace(var.internal_observability_trace_disabled_plugins) != "" ? {
      DD_TRACE_DISABLED_PLUGINS = var.internal_observability_trace_disabled_plugins
    } : {},
  )
  # Use the plan-known enable flag (not the computed secret ARN) so count/for_each stay known during plan.
  license_key_enabled   = var.brainstore_license_key_enabled
  extra_secrets_enabled = length(var.extra_secrets) > 0
  # Strip optional :json-key:version-stage:version-id from ECS valueFrom for IAM Resources.
  extra_secret_arns = [
    for s in var.extra_secrets : regex("^arn:[^:]+:secretsmanager:[^:]+:[^:]+:secret:[^:]+", s.valueFrom)
  ]
  merged_env_vars = merge(local.base_env_vars, var.extra_env_vars)
  # Pin the secret version in valueFrom so rotating the key revises the task definition and rolls the service.
  # Format: arn:...:secret:name:json-key:version-stage:version-id (empty json-key = full secret string).
  gateway_secrets = concat(
    local.license_key_enabled ? [
      {
        name      = "BRAINSTORE_LICENSE_KEY"
        valueFrom = "${var.brainstore_license_key_secret_arn}:::${var.brainstore_license_key_secret_version}"
      }
    ] : [],
    var.extra_secrets,
  )

  gateway_container_definition = {
    name      = local.container_name
    image     = var.container_image
    essential = true
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
    secrets = local.gateway_secrets
    dependsOn = [
      for dep in [
        {
          containerName = "datadog-agent"
          condition     = "START"
        }
      ] : dep if local.observability_enabled
    ]
    logConfiguration = local.gateway_log_configuration
  }

  observability_sidecars = [
    for sidecar in [
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
          {
            name  = "ECS_FARGATE"
            value = "true"
          },
          {
            name  = "DD_SITE"
            value = "${var.internal_observability_region}.datadoghq.com"
          },
          {
            name  = "DD_ENV"
            value = var.internal_observability_env_name
          },
          {
            name  = "DD_SERVICE"
            value = "gateway"
          },
          {
            name  = "DD_VERSION"
            value = local.gateway_version_tag
          },
          {
            name  = "DD_PROCESS_AGENT_ENABLED"
            value = "true"
          },
          {
            name  = "DD_OTLP_CONFIG_RECEIVER_PROTOCOLS_HTTP_ENDPOINT"
            value = "0.0.0.0:4318"
          },
          {
            name  = "DD_LOGS_ENABLED"
            value = "true"
          },
          {
            name  = "DD_OTLP_CONFIG_LOGS_ENABLED"
            value = "true"
          }
        ]
        secrets = [
          {
            name      = "DD_API_KEY"
            valueFrom = local.observability_api_key_value_from
          }
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

  gateway_log_configuration = {
    logDriver = "awslogs"
    options = {
      awslogs-group         = aws_cloudwatch_log_group.service.name
      awslogs-region        = data.aws_region.current.region
      awslogs-stream-prefix = "gateway"
    }
  }

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
  name              = "/ecs/${var.deployment_name}/gateway"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = merge({
    Name = "${var.deployment_name}-gateway-logs"
  }, local.common_tags)
}

resource "aws_security_group" "task" {
  name        = "${var.deployment_name}-gateway-task"
  description = "Security group for gateway ECS tasks"
  vpc_id      = var.vpc_id
  tags = merge({
    Name = "${var.deployment_name}-gateway-task"
  }, local.common_tags)
}

resource "aws_security_group_rule" "task_ingress_from_alb" {
  type                     = "ingress"
  from_port                = local.container_port
  to_port                  = local.container_port
  protocol                 = "tcp"
  source_security_group_id = var.alb_security_group_id
  description              = "Allow inbound traffic from gateway ALB to gateway tasks"
  security_group_id        = aws_security_group.task.id
}

resource "aws_security_group_rule" "task_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow all outbound traffic from gateway ECS tasks"
  security_group_id = aws_security_group.task.id
}

resource "aws_vpc_security_group_ingress_rule" "cache_allow_ingress_from_gateway_tasks" {
  from_port                    = var.redis_port
  to_port                      = var.redis_port
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.task.id
  description                  = "Allow inbound traffic from gateway tasks."

  security_group_id = var.redis_security_group_id
  tags              = local.common_tags
}

resource "aws_iam_role" "task_execution" {
  name               = "${var.deployment_name}-gateway-task-exec"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume_role.json
  tags = merge({
    Name = "${var.deployment_name}-gateway-task-exec"
  }, local.common_tags)
}

resource "aws_iam_role_policy_attachment" "task_execution_default" {
  role       = aws_iam_role.task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "task_execution_secrets" {
  count = local.observability_enabled || local.license_key_enabled || local.extra_secrets_enabled ? 1 : 0

  name = "${var.deployment_name}-gateway-task-exec-secrets"
  role = aws_iam_role.task_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
        ]
        Resource = compact(concat(
          [
            local.observability_enabled ? var.internal_observability_api_key_secret_arn : "",
            local.license_key_enabled ? var.brainstore_license_key_secret_arn : "",
          ],
          local.extra_secret_arns,
        ))
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
        ]
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

resource "aws_iam_role" "task" {
  name                 = "${var.deployment_name}-gateway-task"
  assume_role_policy   = data.aws_iam_policy_document.ecs_task_assume_role.json
  permissions_boundary = var.permissions_boundary_arn
  tags = merge({
    Name = "${var.deployment_name}-gateway-task"
  }, local.common_tags)
}

resource "aws_iam_role_policy" "customer_assume_role" {
  name = "${var.deployment_name}-gateway-customer-assume-role"
  role = aws_iam_role.task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "AssumeRoleInCustomerAccount"
        Effect   = "Allow"
        Action   = "sts:AssumeRole"
        Resource = "*"
        Condition = {
          StringLike = {
            "sts:ExternalId" = "bt:*"
          }
        }
      }
    ]
  })
}

resource "aws_ecs_task_definition" "gateway" {
  family                   = "${var.deployment_name}-gateway"
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

  container_definitions = jsonencode(concat([local.gateway_container_definition], local.observability_sidecars))

  # Ensure GetSecretValue is granted before a revision that references secrets is registered.
  depends_on = [aws_iam_role_policy.task_execution_secrets]

  tags = merge({
    Name = "${var.deployment_name}-gateway"
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

resource "terraform_data" "gateway_http_listener" {
  input = var.gateway_http_listener_arn
}

resource "aws_ecs_service" "gateway" {
  name                              = "${var.deployment_name}-gateway"
  cluster                           = var.ecs_cluster_arn
  task_definition                   = aws_ecs_task_definition.gateway.arn
  desired_count                     = var.min_capacity
  launch_type                       = "FARGATE"
  enable_execute_command            = var.enable_execute_command
  health_check_grace_period_seconds = 60
  wait_for_steady_state             = true

  # This causes instant rollbacks on first deploy. Must be off. (Same as api-ecs.)
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

  # Wait for listener readiness and for task-exec secret IAM before rolling tasks
  # that resolve BRAINSTORE_LICENSE_KEY / DD_API_KEY from Secrets Manager.
  depends_on = [
    terraform_data.gateway_http_listener,
    aws_iam_role_policy.task_execution_secrets,
  ]

  lifecycle {
    ignore_changes = [desired_count]
  }

  tags = merge({
    Name = "${var.deployment_name}-gateway"
  }, local.common_tags)
}
