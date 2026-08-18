# Optional Rust ingest service.
# create_rust_api_ingest stands up the service + TG.
# enable_rust_api_ingest (or rust_api_ingest_traffic_weight while canarying)
# controls ALB ingest path forwarding — see alb-path-routes.tf.

locals {
  braintrust_api_rust_ingest_name = "braintrust-api-rust-ingest"
  rust_api_ingest_version_tag = (
    var.rust_api_ingest_version_override != null
    ? var.rust_api_ingest_version_override
    : try(jsondecode(file("${path.module}/VERSIONS.json"))["api_rust_ingest"], null)
  )

  rust_api_ingest_env_vars = merge(local.merged_env_vars, {
    CLOUDWATCH_METRICS_SERVICE_NAME    = local.braintrust_api_rust_ingest_name
    CLOUDWATCH_METRICS_DEPLOYMENT_NAME = var.deployment_name
    API_RS_PORT                        = "8100"
  })

  # api-rs (public.ecr.aws/braintrust/api-next) listens on 8100 with /health/liveness.
  # Override portMappings + healthCheck from api_container_base (TS defaults to 8000 /).
  rust_api_ingest_container_definitions = jsonencode([
    merge(local.api_container_base, {
      name  = "api"
      image = "${var.rust_api_ingest_container_image_repository}:${coalesce(local.rust_api_ingest_version_tag, "unset")}"
      portMappings = [
        {
          containerPort = 8100
          hostPort      = 8100
          protocol      = "tcp"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = try(aws_cloudwatch_log_group.braintrust_api_rust_ingest[0].name, "/braintrust/${var.deployment_name}/${local.braintrust_api_rust_ingest_name}")
          awslogs-region        = data.aws_region.current.region
          awslogs-stream-prefix = local.braintrust_api_rust_ingest_name
        }
      }
      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:8100${var.rust_api_ingest_health_check_path} || exit 1"]
        interval    = 30
        retries     = 3
        startPeriod = 10
        timeout     = 5
      }
      environment = [
        for key in sort(keys(local.rust_api_ingest_env_vars)) : {
          name  = key
          value = local.rust_api_ingest_env_vars[key]
        }
      ]
    })
  ])
}

resource "aws_cloudwatch_log_group" "braintrust_api_rust_ingest" {
  count = var.create_rust_api_ingest ? 1 : 0

  name              = "/braintrust/${var.deployment_name}/${local.braintrust_api_rust_ingest_name}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = merge({
    Name = "${var.deployment_name}-${local.braintrust_api_rust_ingest_name}-logs"
  }, local.common_tags)
}

resource "aws_lb_target_group" "braintrust_api_rust_ingest" {
  count = var.create_rust_api_ingest ? 1 : 0

  # Max 32 chars: deployment_name <= 18 + "-api-rs-ing".
  name        = "${var.deployment_name}-api-rs-ing"
  port        = 8100
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.vpc_id

  deregistration_delay = var.target_group_deregistration_delay_seconds

  health_check {
    path                = var.rust_api_ingest_health_check_path
    matcher             = "200-399"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 10
  }

  tags = merge({
    Name = "${var.deployment_name}-${local.braintrust_api_rust_ingest_name}"
  }, local.common_tags)
}

resource "aws_ecs_task_definition" "braintrust_api_rust_ingest" {
  count = var.create_rust_api_ingest ? 1 : 0

  family                   = "${var.deployment_name}-${local.braintrust_api_rust_ingest_name}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = tostring(var.rust_api_ingest_cpu)
  memory                   = tostring(var.rust_api_ingest_memory)
  execution_role_arn       = aws_iam_role.task_execution.arn
  task_role_arn            = var.task_role_arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "ARM64"
  }

  container_definitions = local.rust_api_ingest_container_definitions

  tags = merge({
    Name = "${var.deployment_name}-${local.braintrust_api_rust_ingest_name}"
  }, local.common_tags)

  lifecycle {
    precondition {
      condition     = contains(keys(local.valid_fargate_memory_by_cpu), tostring(var.rust_api_ingest_cpu))
      error_message = "rust_api_ingest_cpu must be a valid Fargate CPU value."
    }
    precondition {
      condition     = contains(local.valid_fargate_memory_by_cpu[tostring(var.rust_api_ingest_cpu)], var.rust_api_ingest_memory)
      error_message = "rust_api_ingest_memory must be a valid Fargate memory value for the configured cpu."
    }
    precondition {
      condition     = local.rust_api_ingest_version_tag != null && trimspace(local.rust_api_ingest_version_tag) != ""
      error_message = "create_rust_api_ingest requires rust_api_ingest_version_override or VERSIONS.json api_rust_ingest."
    }
    precondition {
      condition     = trimspace(var.rust_api_ingest_container_image_repository) != ""
      error_message = "create_rust_api_ingest requires rust_api_ingest_container_image_repository."
    }
  }
}

resource "aws_ecs_service" "braintrust_api_rust_ingest" {
  count = var.create_rust_api_ingest ? 1 : 0

  name                              = "${var.deployment_name}-${local.braintrust_api_rust_ingest_name}"
  cluster                           = var.ecs_cluster_arn
  task_definition                   = aws_ecs_task_definition.braintrust_api_rust_ingest[0].arn
  desired_count                     = var.rust_api_ingest_min_count
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
    target_group_arn = aws_lb_target_group.braintrust_api_rust_ingest[0].arn
    container_name   = "api"
    container_port   = 8100
  }

  depends_on = [aws_lb_listener_rule.alb_path_routes]

  lifecycle {
    create_before_destroy = false
    ignore_changes        = [desired_count]
  }

  tags = merge({
    Name = "${var.deployment_name}-${local.braintrust_api_rust_ingest_name}"
  }, local.common_tags)
}

resource "aws_appautoscaling_target" "braintrust_api_rust_ingest" {
  count = var.create_rust_api_ingest ? 1 : 0

  max_capacity       = var.rust_api_ingest_max_count
  min_capacity       = var.rust_api_ingest_min_count
  resource_id        = "service/${var.ecs_cluster_name}/${aws_ecs_service.braintrust_api_rust_ingest[0].name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "braintrust_api_rust_ingest_cpu_target" {
  count = var.create_rust_api_ingest ? 1 : 0

  name               = "${var.deployment_name}-api-rust-ingest-cpu-target"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.braintrust_api_rust_ingest[0].resource_id
  scalable_dimension = aws_appautoscaling_target.braintrust_api_rust_ingest[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.braintrust_api_rust_ingest[0].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }

    target_value       = var.rust_api_ingest_cpu_autoscaling.target_value
    scale_in_cooldown  = var.rust_api_ingest_cpu_autoscaling.scale_in_cooldown
    scale_out_cooldown = var.rust_api_ingest_cpu_autoscaling.scale_out_cooldown
  }
}
