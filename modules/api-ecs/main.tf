locals {
  api_version_tag       = var.api_version_override != null ? var.api_version_override : jsondecode(file("${path.module}/VERSIONS.json"))["api"]
  observability_enabled = var.internal_observability_api_key_secret_arn != ""

  common_tags = merge({
    BraintrustDeploymentName = var.deployment_name
  }, var.custom_tags)

  using_brainstore_writer      = var.brainstore_writer_hostname != null && var.brainstore_writer_hostname != ""
  using_brainstore_fast_reader = var.brainstore_fast_reader_hostname != null && var.brainstore_fast_reader_hostname != ""
  https_url                    = "https://${var.fqdn}"

  base_env_vars = merge({
    ORG_NAME                                          = var.braintrust_org_name
    PRIMARY_ORG_NAME                                  = var.primary_org_name
    BRAINTRUST_DEPLOYMENT_NAME                        = var.deployment_name
    RESPONSE_BUCKET                                   = var.response_bucket
    CODE_BUNDLE_BUCKET                                = var.code_bundle_bucket
    WHITELISTED_ORIGINS                               = join(",", var.whitelisted_origins)
    OUTBOUND_RATE_LIMIT_WINDOW_MINUTES                = tostring(var.outbound_rate_limit_window_minutes)
    OUTBOUND_RATE_LIMIT_MAX_REQUESTS                  = tostring(var.outbound_rate_limit_max_requests)
    QUARANTINE_INVOKE_ROLE                            = var.use_quarantine_vpc && var.quarantine_invoke_role_arn != null ? var.quarantine_invoke_role_arn : ""
    QUARANTINE_FUNCTION_ROLE                          = var.use_quarantine_vpc && var.quarantine_function_role_arn != null ? var.quarantine_function_role_arn : ""
    QUARANTINE_PRIVATE_SUBNET_1_ID                    = var.use_quarantine_vpc ? var.quarantine_vpc_private_subnets[0] : ""
    QUARANTINE_PRIVATE_SUBNET_2_ID                    = var.use_quarantine_vpc ? var.quarantine_vpc_private_subnets[1] : ""
    QUARANTINE_PRIVATE_SUBNET_3_ID                    = var.use_quarantine_vpc ? var.quarantine_vpc_private_subnets[2] : ""
    QUARANTINE_PUB_PRIVATE_VPC_DEFAULT_SECURITY_GROUP = var.use_quarantine_vpc && var.quarantine_lambda_security_group_id != null ? var.quarantine_lambda_security_group_id : ""
    QUARANTINE_PUB_PRIVATE_VPC_ID                     = var.use_quarantine_vpc ? var.quarantine_vpc_id : ""
    QUARANTINE_REGION                                 = var.use_quarantine_vpc ? data.aws_region.current.region : ""
    BRAINSTORE_ENABLED                                = "true"
    BRAINSTORE_DEFAULT                                = "force"
    BRAINSTORE_URL                                    = "http://${var.brainstore_hostname}:${var.brainstore_port}"
    BRAINSTORE_WRITER_URL                             = local.using_brainstore_writer ? "http://${var.brainstore_writer_hostname}:${var.brainstore_port}" : ""
    BRAINSTORE_REALTIME_WAL_BUCKET                    = var.brainstore_s3_bucket_name != null ? var.brainstore_s3_bucket_name : ""
    BRAINSTORE_INSERT_ROW_REFS                        = "true"
    CONTROL_PLANE_TELEMETRY                           = var.monitoring_telemetry
    TELEMETRY_DISABLE_AGGREGATION                     = tostring(var.disable_billing_telemetry_aggregation)
    TELEMETRY_LOG_LEVEL                               = var.billing_telemetry_log_level
    INSERT_LOGS2                                      = "true"
    NODE_MEMORY_PERCENT                               = "80"
    AI_PROXY_FN_URL                                   = "http://127.0.0.1:8000"
    DISABLE_ASYNC_SCORING                             = "false"
    DISABLE_ATTACHMENT_OPTIMIZATION                   = "false"
    ENABLE_DEEP_SEARCH_LOGGING                        = "false"
    ENABLE_RUNTIME_METRICS                            = "false"
    TS_API_HOST                                       = "0.0.0.0"
    TS_API_PORT                                       = "8000"
    PROXY_URL                                         = "http://127.0.0.1:8000/v1/proxy"
    TS_API_ASYNC_SCORING_PROXY_URL                    = "http://127.0.0.1:8000"
    },
    # In transitional ECS mode, Lambda services still own background loops.
    var.private_api_ecs_mode ? {} : {
      BRAINSTORE_DISABLE_ETL_LOOP     = "true"
      AUTOMATION_CRON_MAX_CONCURRENCY = "0"
      DISABLE_LOCAL_BACKGROUND_LOOPS  = "true"
    },
    # Transitional ECS calls the Lambda AI proxy; private ECS-only keeps proxy work in-process.
    !var.private_api_ecs_mode ? (
      var.quarantine_proxy_url != null ? (
        trimspace(var.quarantine_proxy_url) != "" ? {
          QUARANTINE_PROXY_URL = var.quarantine_proxy_url
        } : {}
      ) : {}
    ) : {},
    # Private ECS-only can fall back to in-process execution when quarantine VPC is disabled.
    var.allow_code_function_execution ? {
      ALLOW_CODE_FUNCTION_EXECUTION = "true"
    } : {},
    local.using_brainstore_fast_reader ? {
      BRAINSTORE_FAST_READER_URL           = "http://${var.brainstore_fast_reader_hostname}:${var.brainstore_port}"
      BRAINSTORE_FAST_READER_QUERY_SOURCES = "summaryPaginatedObjectViewer [realtime],summaryPaginatedObjectViewer,a602c972-1843-4ee1-b6bc-d3c1075cd7e7,traceQueryFn-id,traceQueryFn-rootSpanId,fullSpanQueryFn-root_span_id,fullSpanQueryFn-id"
    } : {},
    var.brainstore_wal_footer_version != "" ? {
      BRAINSTORE_WAL_FOOTER_VERSION = var.brainstore_wal_footer_version
    } : {},
    var.skip_pg_for_brainstore_objects != "" ? {
      SKIP_PG_FOR_BRAINSTORE_OBJECTS = var.skip_pg_for_brainstore_objects
    } : {},
    (var.brainstore_wal_footer_version != "" || var.skip_pg_for_brainstore_objects != "") ? {
      BRAINSTORE_WAL_USE_EFFICIENT_FORMAT = "true"
    } : {},
    var.brainstore_enable_export ? {
      BRAINSTORE_EXPORT_MIGRATION_ENABLED = "true"
    } : {},
    var.brainstore_etl_batch_size != null ? {
      BRAINSTORE_BACKFILL_HISTORICAL_BATCH_SIZE = tostring(var.brainstore_etl_batch_size)
    } : {},
  )

  merged_env_vars = merge(local.base_env_vars, var.extra_env_vars)

  api_container_definition = merge(
    {
      name      = "api"
      image     = "${var.container_image_repository}:${local.api_version_tag}"
      essential = true
      linuxParameters = {
        initProcessEnabled = true
      }
      portMappings = [
        {
          containerPort = 8000
          hostPort      = 8000
          protocol      = "tcp"
        }
      ]
      environment = [
        for key in sort(keys(local.merged_env_vars)) : {
          name  = key
          value = local.merged_env_vars[key]
        }
      ]
      secrets = [
        {
          name      = "FUNCTION_SECRET_KEY"
          valueFrom = var.function_tools_secret_arn
        },
        {
          name      = "PG_URL"
          valueFrom = var.database_url_secret_arn
        },
        {
          name      = "REDIS_URL"
          valueFrom = var.redis_url_secret_arn
        },
        {
          name      = "SERVICE_TOKEN_SECRET_KEY"
          valueFrom = var.function_tools_secret_arn
        }
      ]
      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:8000/ || exit 1"]
        interval    = 30
        retries     = 3
        startPeriod = 10
        timeout     = 5
      }
      dependsOn = [
        for dep in [
          {
            containerName = "log-router"
            condition     = "START"
          },
          {
            containerName = "datadog-agent"
            condition     = "START"
          }
        ] : dep if local.observability_enabled
      ]
      logConfiguration = local.api_log_configuration
      mountPoints      = []
      systemControls   = []
      volumesFrom      = []
    }
  )

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
            value = "braintrust-api"
          },
          {
            name  = "DD_VERSION"
            value = local.api_version_tag
          },
          {
            name  = "DD_PROCESS_AGENT_ENABLED"
            value = "true"
          },
          {
            name  = "DD_OTLP_CONFIG_RECEIVER_PROTOCOLS_HTTP_ENDPOINT"
            value = "0.0.0.0:4318"
          }
        ]
        secrets = [
          {
            name      = "DD_API_KEY"
            valueFrom = var.internal_observability_api_key_secret_arn
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

  api_log_configuration = jsondecode(local.observability_enabled ? jsonencode({
    logDriver = "awsfirelens"
    options = {
      Name           = "datadog"
      Host           = "http-intake.logs.${var.internal_observability_region}.datadoghq.com"
      TLS            = "on"
      provider       = "ecs"
      dd_service     = "braintrust-api"
      dd_source      = "nodejs"
      dd_message_key = "msg"
      dd_tags        = "env:${var.internal_observability_env_name}"
      compress       = "gzip"
    }
    secretOptions = [
      {
        name      = "apikey"
        valueFrom = var.internal_observability_api_key_secret_arn
      }
    ]
    }) : jsonencode({
    logDriver = "awslogs"
    options = {
      awslogs-group         = aws_cloudwatch_log_group.service.name
      awslogs-region        = data.aws_region.current.region
      awslogs-stream-prefix = "api-ecs"
    }
  }))

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

resource "aws_cloudwatch_log_group" "service" {
  name              = "/braintrust/${var.deployment_name}/api-ecs"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = merge({
    Name = "${var.deployment_name}-api-ecs-logs"
  }, local.common_tags)
}

resource "aws_security_group" "alb" {
  name        = "${var.deployment_name}-api-ecs-alb"
  description = "Security group for API ECS ALB"
  vpc_id      = var.vpc_id
  tags = merge({
    Name = "${var.deployment_name}-api-ecs-alb"
  }, local.common_tags)
}

resource "aws_security_group_rule" "alb_ingress_8000_from_authorized_security_groups" {
  for_each = var.internal_authorized_security_groups

  type                     = "ingress"
  from_port                = 8000
  to_port                  = 8000
  protocol                 = "tcp"
  source_security_group_id = each.value
  description              = "Allow API ECS HTTP traffic from ${each.key}."
  security_group_id        = aws_security_group.alb.id
}

resource "aws_security_group_rule" "alb_ingress_http_redirect_from_authorized_security_groups" {
  for_each = var.authorized_security_groups

  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  source_security_group_id = each.value
  description              = "Allow HTTP redirect traffic from ${each.key}."
  security_group_id        = aws_security_group.alb.id
}

resource "aws_security_group_rule" "alb_ingress_http_redirect_from_authorized_cidr_blocks" {
  for_each = toset(var.authorized_cidr_blocks)

  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = [each.value]
  description       = "Allow HTTP redirect traffic from authorized CIDR ${each.value}."
  security_group_id = aws_security_group.alb.id
}

resource "aws_security_group_rule" "alb_ingress_https_from_authorized_security_groups" {
  for_each = var.authorized_security_groups

  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = each.value
  description              = "Allow HTTPS traffic from ${each.key}."
  security_group_id        = aws_security_group.alb.id
}

resource "aws_security_group_rule" "alb_ingress_https_from_authorized_cidr_blocks" {
  for_each = toset(var.authorized_cidr_blocks)

  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = [each.value]
  description       = "Allow HTTPS traffic from authorized CIDR ${each.value}."
  security_group_id = aws_security_group.alb.id
}

resource "aws_security_group_rule" "alb_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow all outbound traffic from API ECS ALB."
  security_group_id = aws_security_group.alb.id
}

resource "aws_security_group_rule" "task_ingress_from_alb" {
  type                     = "ingress"
  from_port                = 8000
  to_port                  = 8000
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb.id
  description              = "Allow inbound traffic from API ECS ALB to API ECS tasks."
  security_group_id        = var.task_security_group_id
}

resource "aws_lb" "api_ecs" {
  name               = "${var.deployment_name}-api-ecs"
  internal           = true
  load_balancer_type = "application"
  subnets            = var.private_subnet_ids
  security_groups    = [aws_security_group.alb.id]

  idle_timeout                     = 900
  client_keep_alive                = 3600
  enable_deletion_protection       = false
  enable_http2                     = true
  desync_mitigation_mode           = "defensive"
  enable_cross_zone_load_balancing = true

  tags = merge({
    Name = "${var.deployment_name}-api-ecs"
  }, local.common_tags)
}

resource "aws_lb_target_group" "api_ecs" {
  name        = "${var.deployment_name}-api-ecs"
  port        = 8000
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.vpc_id

  deregistration_delay = var.target_group_deregistration_delay_seconds

  health_check {
    path                = "/"
    matcher             = "200-399"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 10
  }

  tags = merge({
    Name = "${var.deployment_name}-api-ecs"
  }, local.common_tags)
}

resource "aws_lb_listener" "api_ecs_http" {
  load_balancer_arn = aws_lb.api_ecs.arn
  port              = 8000
  protocol          = "HTTP"

  default_action {
    type = "forward"

    forward {
      target_group {
        arn = aws_lb_target_group.api_ecs.arn
      }
    }
  }
}

resource "aws_lb_listener" "api_ecs_http_redirect" {
  load_balancer_arn = aws_lb.api_ecs.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener" "api_ecs_https" {
  load_balancer_arn = aws_lb.api_ecs.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.acm_certificate_arn

  default_action {
    type = "forward"

    forward {
      target_group {
        arn = aws_lb_target_group.api_ecs.arn
      }
    }
  }
}

resource "aws_ssm_parameter" "api_url" {
  name        = "/braintrust/${var.deployment_name}/ecs-api-url"
  type        = "String"
  value       = "http://${aws_lb.api_ecs.dns_name}:8000"
  description = "API ECS URL for Brainstore"

  tags = local.common_tags
}

resource "aws_ecs_task_definition" "api_ecs" {
  family                   = "${var.deployment_name}-api-ecs"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = tostring(var.cpu)
  memory                   = tostring(var.memory)
  execution_role_arn       = aws_iam_role.task_execution.arn
  task_role_arn            = var.task_role_arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "ARM64"
  }

  container_definitions = jsonencode(concat([local.api_container_definition], local.observability_sidecars))

  tags = merge({
    Name = "${var.deployment_name}-api-ecs"
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

resource "aws_ecs_service" "api_ecs" {
  name                              = "${var.deployment_name}-api-ecs"
  cluster                           = var.ecs_cluster_arn
  task_definition                   = aws_ecs_task_definition.api_ecs.arn
  desired_count                     = var.min_count
  launch_type                       = "FARGATE"
  force_new_deployment              = true
  propagate_tags                    = "SERVICE"
  enable_ecs_managed_tags           = true
  enable_execute_command            = var.enable_execute_command
  health_check_grace_period_seconds = 60
  wait_for_steady_state             = true
  sigint_rollback                   = true

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [var.task_security_group_id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.api_ecs.arn
    container_name   = "api"
    container_port   = 8000
  }

  depends_on = [
    aws_lb_listener.api_ecs_http,
    aws_lb_listener.api_ecs_https,
  ]

  lifecycle {
    ignore_changes = [desired_count]
  }

  tags = merge({
    Name = "${var.deployment_name}-api-ecs"
  }, local.common_tags)
}
