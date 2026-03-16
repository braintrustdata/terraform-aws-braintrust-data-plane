locals {
  common_tags = merge({
    BraintrustDeploymentName = var.deployment_name
  }, var.custom_tags)

  container_name = "gateway"
  container_port = 8080
  base_env_vars = {
    GATEWAY_ENV        = "production"
    BRAINTRUST_APP_URL = var.braintrust_app_url
    BRAINTRUST_API_URL = var.braintrust_api_url

    COMPLETIONS_CACHE_REDIS_URL = "redis://${var.redis_host}:${var.redis_port}"
    AUTH_CACHE_REDIS_URL        = "redis://${var.redis_host}:${var.redis_port}"
    GATEWAY_JSON_LOGS           = "true"
    OTLP_HTTP_ENDPOINT          = "https://www.braintrust.dev/api/pulse/otel"
  }
  plain_license_env_var = var.brainstore_license_key == null ? {} : {
    BRAINSTORE_LICENSE_KEY = var.brainstore_license_key
  }
  merged_env_vars = merge(local.base_env_vars, local.plain_license_env_var, var.extra_env_vars)

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

data "aws_vpc" "selected" {
  id = var.vpc_id
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

resource "aws_cloudwatch_log_group" "service" {
  name              = "/ecs/${var.deployment_name}/gateway"
  retention_in_days = var.log_retention_days

  tags = merge({
    Name = "${var.deployment_name}-gateway-logs"
  }, local.common_tags)
}

resource "aws_security_group" "alb" {
  name        = "${var.deployment_name}-gateway-alb"
  description = "Security group for private gateway ALB"
  vpc_id      = var.vpc_id
  tags = merge({
    Name = "${var.deployment_name}-gateway-alb"
  }, local.common_tags)
}

resource "aws_security_group_rule" "alb_ingress_vpc" {
  count = length(var.allowed_source_security_group_ids) == 0 ? 1 : 0

  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = [data.aws_vpc.selected.cidr_block]
  description       = "Allow HTTP traffic from within the VPC"
  security_group_id = aws_security_group.alb.id
}

resource "aws_security_group_rule" "alb_ingress_from_source_sg" {
  for_each = toset(var.allowed_source_security_group_ids)

  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  source_security_group_id = each.value
  description              = "Allow HTTP traffic from allowed source security groups"
  security_group_id        = aws_security_group.alb.id
}

resource "aws_security_group_rule" "alb_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow all outbound traffic from gateway ALB"
  security_group_id = aws_security_group.alb.id
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
  source_security_group_id = aws_security_group.alb.id
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
  description                  = "Allow Redis inbound to gateway cache from gateway tasks."

  security_group_id = var.cache_security_group_id
  tags              = local.common_tags
}

resource "aws_lb" "gateway" {
  name               = "${var.deployment_name}-gateway"
  internal           = true
  load_balancer_type = "application"
  subnets            = var.private_subnet_ids
  security_groups    = [aws_security_group.alb.id]
  tags = merge({
    Name = "${var.deployment_name}-gateway"
  }, local.common_tags)
}

resource "aws_lb_target_group" "gateway" {
  name        = "${var.deployment_name}-gateway"
  port        = local.container_port
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.vpc_id

  health_check {
    path                = "/"
    matcher             = "200"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
  }

  tags = merge({
    Name = "${var.deployment_name}-gateway"
  }, local.common_tags)
}

resource "aws_lb_listener" "gateway_http" {
  load_balancer_arn = aws_lb.gateway.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.gateway.arn
  }
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

resource "aws_iam_role" "task" {
  name               = "${var.deployment_name}-gateway-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume_role.json
  tags = merge({
    Name = "${var.deployment_name}-gateway-task"
  }, local.common_tags)
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

  container_definitions = jsonencode([
    {
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
          awslogs-stream-prefix = "gateway"
        }
      }
    }
  ])

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

resource "aws_ecs_service" "gateway" {
  name                              = "${var.deployment_name}-gateway"
  cluster                           = var.ecs_cluster_arn
  task_definition                   = aws_ecs_task_definition.gateway.arn
  desired_count                     = var.min_capacity
  launch_type                       = "FARGATE"
  enable_execute_command            = var.enable_execute_command
  health_check_grace_period_seconds = var.health_check_grace_period_seconds
  wait_for_steady_state             = true

  deployment_circuit_breaker {
    enable   = var.enable_deployment_circuit_breaker
    rollback = var.deployment_circuit_breaker_rollback
  }

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.task.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.gateway.arn
    container_name   = local.container_name
    container_port   = local.container_port
  }

  depends_on = [aws_lb_listener.gateway_http]

  lifecycle {
    ignore_changes = [desired_count]
  }

  tags = merge({
    Name = "${var.deployment_name}-gateway"
  }, local.common_tags)
}
