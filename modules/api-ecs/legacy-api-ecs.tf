# Legacy single `api-ecs` service, kept running alongside the new braintrust-api
# services for a zero-downtime, rollback-capable migration. These resources are
# intentionally unconditional: they stay in code during the migration release so
# the new services can come up additively (nothing is destroyed during the
# cutover) and traffic can be flipped back to legacy by setting
# enable_full_ecs_api back to false. A follow-up release deletes this file to
# tear the legacy service down once the new services are verified.
#
# The definitions mirror the pre-migration module so this release produces no
# diff against the already-running service (which would otherwise trigger an
# unwanted redeploy of the live legacy service).

locals {
  legacy_api_log_configuration = jsondecode(local.observability_enabled ? jsonencode({
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

  legacy_observability_sidecars = [
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
          { name = "DD_SERVICE", value = "braintrust-api" },
          { name = "DD_VERSION", value = local.api_version_tag },
          { name = "DD_PROCESS_AGENT_ENABLED", value = "true" },
          { name = "DD_OTLP_CONFIG_RECEIVER_PROTOCOLS_HTTP_ENDPOINT", value = "0.0.0.0:4318" }
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

  # Reuses the shared container base and merged env vars (identical to the
  # pre-migration definition), but with the legacy log group / stream prefix so
  # the rendered task definition matches the running one byte-for-byte.
  legacy_api_container_definition = merge(local.api_container_base, {
    dependsOn        = local.api_container_depends_on
    logConfiguration = local.legacy_api_log_configuration
    environment = [
      for key in sort(keys(local.legacy_api_env_vars)) : {
        name  = key
        value = local.legacy_api_env_vars[key]
      }
    ]
  })
}

resource "aws_cloudwatch_log_group" "service" {
  name              = "/braintrust/${var.deployment_name}/api-ecs"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = merge({
    Name = "${var.deployment_name}-api-ecs-logs"
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

resource "aws_ecs_task_definition" "api_ecs" {
  family                   = "${var.deployment_name}-api-ecs"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = tostring(var.legacy_api_ecs_cpu)
  memory                   = tostring(var.legacy_api_ecs_memory)
  execution_role_arn       = aws_iam_role.task_execution.arn
  task_role_arn            = var.task_role_arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "ARM64"
  }

  container_definitions = jsonencode(concat([local.legacy_api_container_definition], local.legacy_observability_sidecars))

  tags = merge({
    Name = "${var.deployment_name}-api-ecs"
  }, local.common_tags)

  lifecycle {
    precondition {
      condition     = contains(keys(local.valid_fargate_memory_by_cpu), tostring(var.legacy_api_ecs_cpu))
      error_message = "legacy_api_ecs_cpu must be a valid Fargate CPU value."
    }
    precondition {
      condition     = contains(local.valid_fargate_memory_by_cpu[tostring(var.legacy_api_ecs_cpu)], var.legacy_api_ecs_memory)
      error_message = "legacy_api_ecs_memory must be a valid Fargate memory value for the configured cpu."
    }
  }
}

resource "aws_ecs_service" "api_ecs" {
  name                              = "${var.deployment_name}-api-ecs"
  cluster                           = var.ecs_cluster_arn
  task_definition                   = aws_ecs_task_definition.api_ecs.arn
  desired_count                     = var.legacy_api_ecs_min_count
  launch_type                       = "FARGATE"
  force_new_deployment              = true
  propagate_tags                    = "SERVICE"
  enable_ecs_managed_tags           = true
  enable_execute_command            = var.enable_execute_command
  health_check_grace_period_seconds = 60
  wait_for_steady_state             = true

  # This causes instant rollbacks on first deploy. Must be off.
  sigint_rollback = false

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
  ]

  lifecycle {
    ignore_changes = [desired_count]
  }

  tags = merge({
    Name = "${var.deployment_name}-api-ecs"
  }, local.common_tags)
}

resource "aws_appautoscaling_target" "api_ecs" {
  max_capacity       = var.legacy_api_ecs_max_count
  min_capacity       = var.legacy_api_ecs_min_count
  resource_id        = "service/${var.ecs_cluster_name}/${aws_ecs_service.api_ecs.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "api_ecs_cpu_target" {
  name               = "${var.deployment_name}-api-ecs-cpu-target"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.api_ecs.resource_id
  scalable_dimension = aws_appautoscaling_target.api_ecs.scalable_dimension
  service_namespace  = aws_appautoscaling_target.api_ecs.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }

    target_value       = var.legacy_api_ecs_cpu_target_value
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}

resource "aws_appautoscaling_policy" "api_ecs_memory_target" {
  name               = "${var.deployment_name}-api-ecs-memory-target"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.api_ecs.resource_id
  scalable_dimension = aws_appautoscaling_target.api_ecs.scalable_dimension
  service_namespace  = aws_appautoscaling_target.api_ecs.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }

    target_value       = var.legacy_api_ecs_memory_target_value
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}
