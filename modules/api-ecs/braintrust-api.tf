locals {
  braintrust_api_name = "braintrust-api"
}

resource "aws_ecs_task_definition" "braintrust_api" {
  family                   = "${var.deployment_name}-${local.braintrust_api_name}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = tostring(var.braintrust_api_cpu)
  memory                   = tostring(var.braintrust_api_memory)
  execution_role_arn       = aws_iam_role.task_execution.arn
  task_role_arn            = var.task_role_arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "ARM64"
  }

  container_definitions = local.api_container_definitions[local.braintrust_api_name]

  tags = merge({
    Name = "${var.deployment_name}-${local.braintrust_api_name}"
  }, local.common_tags)

  lifecycle {
    precondition {
      condition     = contains(keys(local.valid_fargate_memory_by_cpu), tostring(var.braintrust_api_cpu))
      error_message = "braintrust_api_cpu must be a valid Fargate CPU value."
    }
    precondition {
      condition     = contains(local.valid_fargate_memory_by_cpu[tostring(var.braintrust_api_cpu)], var.braintrust_api_memory)
      error_message = "braintrust_api_memory must be a valid Fargate memory value for the configured cpu."
    }
  }
}

resource "aws_ecs_service" "braintrust_api" {
  name                              = "${var.deployment_name}-${local.braintrust_api_name}"
  cluster                           = var.ecs_cluster_arn
  task_definition                   = aws_ecs_task_definition.braintrust_api.arn
  desired_count                     = var.braintrust_api_min_count
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
    target_group_arn = aws_lb_target_group.braintrust_api.arn
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
    Name = "${var.deployment_name}-${local.braintrust_api_name}"
  }, local.common_tags)
}

resource "aws_appautoscaling_target" "braintrust_api" {
  max_capacity       = var.braintrust_api_max_count
  min_capacity       = var.braintrust_api_min_count
  resource_id        = "service/${var.ecs_cluster_name}/${aws_ecs_service.braintrust_api.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "braintrust_api_cpu_target" {
  name               = "${var.deployment_name}-braintrust-api-cpu-target"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.braintrust_api.resource_id
  scalable_dimension = aws_appautoscaling_target.braintrust_api.scalable_dimension
  service_namespace  = aws_appautoscaling_target.braintrust_api.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }

    target_value       = var.braintrust_api_cpu_target_value
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}
