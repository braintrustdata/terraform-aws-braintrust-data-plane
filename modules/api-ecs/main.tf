locals {
  api_version_tag  = var.api_version_override != null ? var.api_version_override : jsondecode(file("${path.module}/VERSIONS.json"))["api"]
  ecs_cluster_name = element(reverse(split("/", var.ecs_cluster_arn)), 0)

  common_tags = merge({
    BraintrustDeploymentName = var.deployment_name
  }, var.custom_tags)

  container_name               = "api"
  brainstore_enabled           = var.brainstore_hostname != null && var.brainstore_hostname != "" && var.brainstore_port != null
  using_brainstore_writer      = var.brainstore_writer_hostname != null && var.brainstore_writer_hostname != ""
  using_brainstore_fast_reader = var.brainstore_fast_reader_hostname != null && var.brainstore_fast_reader_hostname != ""
  brainstore_url               = local.brainstore_enabled ? "http://${var.brainstore_hostname}:${var.brainstore_port}" : ""
  brainstore_writer_url        = local.brainstore_enabled && local.using_brainstore_writer ? "http://${var.brainstore_writer_hostname}:${var.brainstore_port}" : ""
  brainstore_fast_reader_url   = local.brainstore_enabled && local.using_brainstore_fast_reader ? "http://${var.brainstore_fast_reader_hostname}:${var.brainstore_port}" : ""
  brainstore_s3_bucket         = local.brainstore_enabled && var.brainstore_s3_bucket_name != null ? var.brainstore_s3_bucket_name : ""
  base_env_vars = {
    ORG_NAME                                  = var.braintrust_org_name
    PRIMARY_ORG_NAME                          = var.primary_org_name
    BRAINTRUST_DEPLOYMENT_NAME                = var.deployment_name
    PG_URL                                    = "postgres://${var.postgres_username}:${var.postgres_password}@${var.postgres_host}:${var.postgres_port}/postgres?sslmode=require"
    REDIS_URL                                 = "redis://${var.redis_host}:${var.redis_port}"
    REDIS_HOST                                = var.redis_host
    REDIS_PORT                                = tostring(var.redis_port)
    RESPONSE_BUCKET                           = var.response_bucket
    CODE_BUNDLE_BUCKET                        = var.code_bundle_bucket
    FUNCTION_SECRET_KEY                       = var.function_secret_key
    SERVICE_TOKEN_SECRET_KEY                  = var.service_token_secret_key
    BRAINSTORE_ENABLED                        = tostring(local.brainstore_enabled)
    BRAINSTORE_DEFAULT                        = "force"
    BRAINSTORE_URL                            = local.brainstore_url
    BRAINSTORE_WRITER_URL                     = local.brainstore_writer_url
    BRAINSTORE_REALTIME_WAL_BUCKET            = local.brainstore_s3_bucket
    BRAINSTORE_LICENSE_KEY                    = var.brainstore_license_key
    BRAINSTORE_BACKFILL_HISTORICAL_BATCH_SIZE = tostring(var.brainstore_etl_batch_size)
    WHITELISTED_ORIGINS                       = join(",", var.whitelisted_origins)
    OUTBOUND_RATE_LIMIT_WINDOW_MINUTES        = tostring(var.outbound_rate_limit_window_minutes)
    OUTBOUND_RATE_LIMIT_MAX_REQUESTS          = tostring(var.outbound_rate_limit_max_requests)
    CONTROL_PLANE_TELEMETRY                   = var.monitoring_telemetry
    INSERT_LOGS2                              = "true"
    BRAINSTORE_INSERT_ROW_REFS                = "true"
    NODE_MEMORY_PERCENT                       = "80"
    ALLOW_CODE_FUNCTION_EXECUTION             = "false"
  }
  brainstore_wal_footer_env_vars = var.brainstore_wal_footer_version != "" ? {
    BRAINSTORE_WAL_FOOTER_VERSION = var.brainstore_wal_footer_version
  } : {}
  merged_env_vars = merge(
    local.base_env_vars,
    local.using_brainstore_fast_reader ? {
      BRAINSTORE_FAST_READER_URL           = local.brainstore_fast_reader_url
      BRAINSTORE_FAST_READER_QUERY_SOURCES = "summaryPaginatedObjectViewer [realtime],summaryPaginatedObjectViewer,a602c972-1843-4ee1-b6bc-d3c1075cd7e7,traceQueryFn-id,traceQueryFn-rootSpanId,fullSpanQueryFn-root_span_id,fullSpanQueryFn-id"
    } : {},
    local.brainstore_wal_footer_env_vars,
    var.extra_env_vars
  )

  valid_fargate_memory_by_cpu = {
    "256"   = [512, 1024, 2048]
    "512"   = [1024, 2048, 3072, 4096]
    "1024"  = [2048, 3072, 4096, 5120, 6144, 7168, 8192]
    "2048"  = [for value in range(4096, 16385, 1024) : value]
    "4096"  = [for value in range(8192, 30721, 1024) : value]
    "8192"  = [for value in range(16384, 61441, 4096) : value]
    "16384" = [for value in range(32768, 122881, 8192) : value]
  }

  managed_certificate_configuration_ready = var.create_acm_certificate && var.route53_zone_name != null && var.alb_hostname != null
  managed_certificate_arn                 = local.managed_certificate_configuration_ready ? aws_acm_certificate.alb[0].arn : null
  selected_certificate_arn                = var.acm_certificate_arn != null ? var.acm_certificate_arn : local.managed_certificate_arn
  enable_https                            = var.acm_certificate_arn != null || local.managed_certificate_configuration_ready
  cloudfront_origin_protocol_policy       = local.enable_https ? "https-only" : "http-only"
  use_route53                             = var.create_acm_certificate || var.create_dns_record
  alb_subnet_ids                          = var.private_subnet_ids
  route53_zone_fqdn                       = var.route53_zone_name == null ? null : trimsuffix(var.route53_zone_name, ".")
  certificate_domain_name                 = var.alb_hostname != null && var.route53_zone_name != null ? "${var.alb_hostname}.${local.route53_zone_fqdn}" : null
}

data "aws_region" "current" {}

resource "aws_cloudwatch_log_group" "service" {
  name              = "/ecs/${var.deployment_name}/api-ecs"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = merge({
    Name = "${var.deployment_name}-api-ecs-logs"
  }, local.common_tags)
}

resource "aws_lb" "api_ecs" {
  name               = "${var.deployment_name}-api-ecs"
  internal           = true
  load_balancer_type = "application"
  subnets            = local.alb_subnet_ids
  security_groups = compact([
    aws_security_group.alb.id,
    var.allow_cloudfront_origin_facing_traffic ? aws_security_group.alb_cloudfront[0].id : null
  ])

  idle_timeout                     = var.alb_idle_timeout_seconds
  client_keep_alive                = var.alb_client_keep_alive_seconds
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
  port        = var.container_port
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.vpc_id

  deregistration_delay = var.alb_deregistration_delay_seconds

  health_check {
    path                = var.health_check_path
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
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = local.enable_https ? "redirect" : "forward"

    dynamic "redirect" {
      for_each = local.enable_https ? [1] : []
      content {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }

    dynamic "forward" {
      for_each = local.enable_https ? [] : [1]
      content {
        target_group {
          arn = aws_lb_target_group.api_ecs.arn
        }
      }
    }
  }
}

resource "aws_lb_listener" "api_ecs_https" {
  count             = local.enable_https ? 1 : 0
  load_balancer_arn = aws_lb.api_ecs.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-Res-PQ-2025-09"
  certificate_arn   = local.selected_certificate_arn

  default_action {
    type = "forward"

    forward {
      target_group {
        arn = aws_lb_target_group.api_ecs.arn
      }
    }
  }

  depends_on = [aws_acm_certificate_validation.alb]
}


resource "aws_ecs_task_definition" "api_ecs" {
  family                   = "${var.deployment_name}-api-ecs"
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

  container_definitions = jsonencode([
    {
      name      = local.container_name
      image     = "${var.container_image_repository}:${local.api_version_tag}"
      essential = true
      linuxParameters = {
        initProcessEnabled = true
      }
      portMappings = [
        {
          containerPort = var.container_port
          hostPort      = var.container_port
          protocol      = "tcp"
        }
      ]
      environment = [
        for key, value in local.merged_env_vars : {
          name  = key
          value = value
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.service.name
          awslogs-region        = data.aws_region.current.region
          awslogs-stream-prefix = "api-ecs"
        }
      }
    }
  ])

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
  desired_count                     = var.min_capacity
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
    security_groups  = [aws_security_group.task.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.api_ecs.arn
    container_name   = local.container_name
    container_port   = var.container_port
  }

  depends_on = [aws_lb_listener.api_ecs_http]

  lifecycle {
    ignore_changes = [desired_count]
  }

  tags = merge({
    Name = "${var.deployment_name}-api-ecs"
  }, local.common_tags)
}
