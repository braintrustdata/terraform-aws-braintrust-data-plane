locals {
  api_release_version = jsondecode(file("${path.module}/VERSIONS.json"))["api"]
  api_version_tag     = var.api_version_override != null ? var.api_version_override : local.api_release_version
  resolved_container_image = var.container_image != null ? var.container_image : format(
    "public.ecr.aws/braintrust/standalone-api:%s",
    local.api_version_tag
  )

  common_tags = merge({
    BraintrustDeploymentName = var.deployment_name
  }, var.custom_tags)

  container_name = "api"
  base_env_vars = {
    ORG_NAME                           = var.braintrust_org_name
    PRIMARY_ORG_NAME                   = var.primary_org_name
    BRAINTRUST_DEPLOYMENT_NAME         = var.deployment_name
    PG_URL                             = "postgres://${var.postgres_username}:${var.postgres_password}@${var.postgres_host}:${var.postgres_port}/postgres?sslmode=require"
    REDIS_URL                          = "redis://${var.redis_host}:${var.redis_port}"
    REDIS_HOST                         = var.redis_host
    REDIS_PORT                         = tostring(var.redis_port)
    RESPONSE_BUCKET                    = var.response_bucket
    CODE_BUNDLE_BUCKET                 = var.code_bundle_bucket
    FUNCTION_SECRET_KEY                = var.function_secret_key
    SERVICE_TOKEN_SECRET_KEY           = var.service_token_secret_key
    BRAINSTORE_ENABLED                 = "true"
    BRAINSTORE_DEFAULT                 = "force"
    BRAINSTORE_REALTIME_WAL_BUCKET     = var.brainstore_realtime_wal_bucket
    WHITELISTED_ORIGINS                = join(",", var.whitelisted_origins)
    OUTBOUND_RATE_LIMIT_WINDOW_MINUTES = tostring(var.outbound_rate_limit_window_minutes)
    OUTBOUND_RATE_LIMIT_MAX_REQUESTS   = tostring(var.outbound_rate_limit_max_requests)
    CONTROL_PLANE_TELEMETRY            = var.monitoring_telemetry
    INSERT_LOGS2                       = "true"
    BRAINSTORE_INSERT_ROW_REFS         = "true"
  }
  merged_env_vars = merge(
    local.base_env_vars,
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

  managed_certificate_configuration_ready = var.create_acm_certificate && var.create_validation_records && var.route53_zone_name != null && var.alb_hostname != null
  managed_certificate_arn                 = local.managed_certificate_configuration_ready ? aws_acm_certificate.alb[0].arn : null
  selected_certificate_arn                = var.acm_certificate_arn != null ? var.acm_certificate_arn : local.managed_certificate_arn
  enable_https                            = var.alb_enable_https && (var.acm_certificate_arn != null || local.managed_certificate_configuration_ready)
  cloudfront_origin_protocol_policy       = local.enable_https ? "https-only" : "http-only"
  use_route53                             = (var.create_acm_certificate && var.create_validation_records) || var.create_dns_record
  alb_subnet_ids                          = var.private_subnet_ids
  route53_zone_fqdn                       = var.route53_zone_name == null ? null : trimsuffix(var.route53_zone_name, ".")
  certificate_domain_name                 = var.alb_hostname != null && var.route53_zone_name != null ? "${var.alb_hostname}.${local.route53_zone_fqdn}" : null
}

data "aws_region" "current" {}

data "aws_vpc" "current" {
  id = var.vpc_id
}

data "aws_route53_zone" "validation" {
  count = local.use_route53 ? 1 : 0

  name         = local.route53_zone_fqdn != null ? "${local.route53_zone_fqdn}." : "invalid.local."
  private_zone = false
}

data "aws_iam_policy_document" "ecs_task_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "task_exec_ssm_messages" {
  statement {
    actions = [
      "ssmmessages:CreateControlChannel",
      "ssmmessages:CreateDataChannel",
      "ssmmessages:OpenControlChannel",
      "ssmmessages:OpenDataChannel",
    ]
    resources = ["*"]
  }
}

resource "aws_cloudwatch_log_group" "service" {
  name              = "/ecs/${var.deployment_name}/api-ecs"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = merge({
    Name = "${var.deployment_name}-api-ecs-logs"
  }, local.common_tags)
}

resource "aws_security_group" "alb" {
  name        = "${var.deployment_name}-api-ecs-alb"
  description = "Security group for private API-ECS ALB"
  vpc_id      = var.vpc_id
  tags = merge({
    Name = "${var.deployment_name}-api-ecs-alb"
  }, local.common_tags)
}

resource "aws_security_group" "alb_cloudfront" {
  count = var.allow_cloudfront_origin_facing_traffic ? 1 : 0

  name        = "${var.deployment_name}-api-ecs-alb-cloudfront"
  description = "Security group for CloudFront ingress to private API-ECS ALB"
  vpc_id      = var.vpc_id
  tags = merge({
    Name = "${var.deployment_name}-api-ecs-alb-cloudfront"
  }, local.common_tags)
}

resource "aws_security_group_rule" "alb_ingress_http_from_authorized_security_groups" {
  for_each = var.authorized_security_groups

  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  source_security_group_id = each.value
  description              = "Allow HTTP traffic from ${each.key}."
  security_group_id        = aws_security_group.alb.id
}

resource "aws_security_group_rule" "alb_ingress_https_from_authorized_security_groups" {
  for_each = local.enable_https ? var.authorized_security_groups : {}

  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = each.value
  description              = "Allow HTTPS traffic from ${each.key}."
  security_group_id        = aws_security_group.alb.id
}

resource "aws_security_group_rule" "alb_ingress_http_from_cloudfront_origin_facing" {
  count = var.allow_cloudfront_origin_facing_traffic ? 1 : 0

  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = [data.aws_vpc.current.cidr_block]
  description       = "Allow HTTP traffic from VPC CIDR for CloudFront VPC origin to private API-ECS ALB."
  security_group_id = aws_security_group.alb_cloudfront[0].id
}

resource "aws_security_group_rule" "alb_ingress_https_from_cloudfront_origin_facing" {
  count = var.allow_cloudfront_origin_facing_traffic && local.enable_https ? 1 : 0

  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = [data.aws_vpc.current.cidr_block]
  description       = "Allow HTTPS traffic from VPC CIDR for CloudFront VPC origin to private API-ECS ALB."
  security_group_id = aws_security_group.alb_cloudfront[0].id
}

resource "aws_security_group_rule" "alb_cloudfront_egress_all" {
  count = var.allow_cloudfront_origin_facing_traffic ? 1 : 0

  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow all outbound traffic from API-ECS CloudFront ALB security group"
  security_group_id = aws_security_group.alb_cloudfront[0].id
}

resource "aws_security_group_rule" "alb_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow all outbound traffic from API-ECS ALB"
  security_group_id = aws_security_group.alb.id
}

resource "aws_security_group" "task" {
  name        = "${var.deployment_name}-api-ecs-task"
  description = "Security group for API-ECS tasks"
  vpc_id      = var.vpc_id
  tags = merge({
    Name = "${var.deployment_name}-api-ecs-task"
  }, local.common_tags)
}

resource "aws_security_group_rule" "task_ingress_from_alb" {
  type                     = "ingress"
  from_port                = var.container_port
  to_port                  = var.container_port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb.id
  description              = "Allow inbound traffic from API-ECS ALB to API-ECS tasks"
  security_group_id        = aws_security_group.task.id
}

resource "aws_security_group_rule" "task_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow all outbound traffic from API-ECS tasks"
  security_group_id = aws_security_group.task.id
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

  lifecycle {
    precondition {
      condition     = !(var.alb_enable_https && var.create_acm_certificate) || var.create_validation_records
      error_message = "Managed ACM for API-ECS HTTPS requires create_validation_records=true."
    }
  }
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
    matcher             = "200"
    healthy_threshold   = 3
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
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
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

resource "aws_iam_role" "task_execution" {
  name               = "${var.deployment_name}-api-ecs-task-exec"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume_role.json
  tags = merge({
    Name = "${var.deployment_name}-api-ecs-task-exec"
  }, local.common_tags)
}

resource "aws_iam_role_policy_attachment" "task_execution_default" {
  role       = aws_iam_role.task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "task" {
  name               = "${var.deployment_name}-api-ecs-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume_role.json
  tags = merge({
    Name = "${var.deployment_name}-api-ecs-task"
  }, local.common_tags)
}

resource "aws_iam_role_policy" "task_exec_ssm_messages" {
  name   = "${var.deployment_name}-api-ecs-task-exec-ssm-messages"
  role   = aws_iam_role.task.id
  policy = data.aws_iam_policy_document.task_exec_ssm_messages.json
}

resource "aws_iam_role_policy" "task_exec_kms" {
  name = "${var.deployment_name}-api-ecs-task-exec-kms"
  role = aws_iam_role.task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = var.kms_key_arn
      }
    ]
  })
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
      image     = local.resolved_container_image
      essential = true
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

resource "aws_acm_certificate" "alb" {
  count             = var.create_acm_certificate ? 1 : 0
  domain_name       = local.certificate_domain_name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = local.common_tags
}

resource "aws_route53_record" "cert_validation" {
  for_each = var.create_acm_certificate && var.create_validation_records ? {
    for dvo in aws_acm_certificate.alb[0].domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  } : {}

  zone_id = data.aws_route53_zone.validation[0].zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = 60
  records = [each.value.record]
}

resource "aws_route53_record" "alb_alias" {
  count = var.create_dns_record ? 1 : 0

  zone_id = data.aws_route53_zone.validation[0].zone_id
  name    = local.certificate_domain_name
  type    = "A"

  alias {
    name                   = aws_lb.api_ecs.dns_name
    zone_id                = aws_lb.api_ecs.zone_id
    evaluate_target_health = false
  }
}

resource "aws_acm_certificate_validation" "alb" {
  count = var.create_acm_certificate && var.create_validation_records ? 1 : 0

  certificate_arn         = aws_acm_certificate.alb[0].arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}
