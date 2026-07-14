locals {
  braintrust_api_ingest_name = "braintrust-api-ingest"
}

resource "aws_ecs_task_definition" "braintrust_api_ingest" {
  family                   = "${var.deployment_name}-${local.braintrust_api_ingest_name}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = tostring(var.braintrust_api_ingest_cpu)
  memory                   = tostring(var.braintrust_api_ingest_memory)
  execution_role_arn       = aws_iam_role.task_execution.arn
  task_role_arn            = var.task_role_arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "ARM64"
  }

  container_definitions = local.api_container_definitions[local.braintrust_api_ingest_name]

  tags = merge({
    Name = "${var.deployment_name}-${local.braintrust_api_ingest_name}"
  }, local.common_tags)

  lifecycle {
    precondition {
      condition     = contains(keys(local.valid_fargate_memory_by_cpu), tostring(var.braintrust_api_ingest_cpu))
      error_message = "braintrust_api_ingest_cpu must be a valid Fargate CPU value."
    }
    precondition {
      condition     = contains(local.valid_fargate_memory_by_cpu[tostring(var.braintrust_api_ingest_cpu)], var.braintrust_api_ingest_memory)
      error_message = "braintrust_api_ingest_memory must be a valid Fargate memory value for the configured cpu."
    }
  }
}

resource "aws_ecs_service" "braintrust_api_ingest" {
  name                              = "${var.deployment_name}-${local.braintrust_api_ingest_name}"
  cluster                           = var.ecs_cluster_arn
  task_definition                   = aws_ecs_task_definition.braintrust_api_ingest.arn
  desired_count                     = var.braintrust_api_ingest_min_count
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
    target_group_arn = aws_lb_target_group.braintrust_api_ingest.arn
    container_name   = "api"
    container_port   = 8000
  }

  # Path rules associate this target group with the ALB, which ECS requires
  # before CreateService will attach the service.
  depends_on = [aws_lb_listener_rule.alb_path_routes]

  lifecycle {
    create_before_destroy = false
    ignore_changes        = [desired_count]
  }

  tags = merge({
    Name = "${var.deployment_name}-${local.braintrust_api_ingest_name}"
  }, local.common_tags)
}

resource "aws_appautoscaling_target" "braintrust_api_ingest" {
  max_capacity       = var.braintrust_api_ingest_max_count
  min_capacity       = var.braintrust_api_ingest_min_count
  resource_id        = "service/${var.ecs_cluster_name}/${aws_ecs_service.braintrust_api_ingest.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "braintrust_api_ingest_cpu_target" {
  name               = "${var.deployment_name}-braintrust-api-ingest-cpu-target"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.braintrust_api_ingest.resource_id
  scalable_dimension = aws_appautoscaling_target.braintrust_api_ingest.scalable_dimension
  service_namespace  = aws_appautoscaling_target.braintrust_api_ingest.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }

    target_value       = var.braintrust_api_ingest_cpu_autoscaling.target_value
    scale_in_cooldown  = var.braintrust_api_ingest_cpu_autoscaling.scale_in_cooldown
    scale_out_cooldown = var.braintrust_api_ingest_cpu_autoscaling.scale_out_cooldown
  }
}

resource "aws_appautoscaling_policy" "braintrust_api_ingest_event_loop_target" {
  name               = "${var.deployment_name}-braintrust-api-ingest-event-loop-target"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.braintrust_api_ingest.resource_id
  scalable_dimension = aws_appautoscaling_target.braintrust_api_ingest.scalable_dimension
  service_namespace  = aws_appautoscaling_target.braintrust_api_ingest.service_namespace

  target_tracking_scaling_policy_configuration {
    customized_metric_specification {
      metric_name = "EventLoopUtilizationPercent"
      namespace   = "Braintrust/Api"
      statistic   = "Average"

      dimensions {
        name  = "ServiceName"
        value = local.braintrust_api_ingest_name
      }

      dimensions {
        name  = "DeploymentName"
        value = var.deployment_name
      }
    }

    target_value       = var.braintrust_api_ingest_event_loop_utilization_autoscaling.target_value
    scale_in_cooldown  = var.braintrust_api_ingest_event_loop_utilization_autoscaling.scale_in_cooldown
    scale_out_cooldown = var.braintrust_api_ingest_event_loop_utilization_autoscaling.scale_out_cooldown
  }
}

resource "aws_appautoscaling_policy" "braintrust_api_ingest_event_loop_delay_step" {
  name               = "${var.deployment_name}-braintrust-api-ingest-event-loop-delay-step"
  policy_type        = "StepScaling"
  resource_id        = aws_appautoscaling_target.braintrust_api_ingest.resource_id
  scalable_dimension = aws_appautoscaling_target.braintrust_api_ingest.scalable_dimension
  service_namespace  = aws_appautoscaling_target.braintrust_api_ingest.service_namespace

  step_scaling_policy_configuration {
    adjustment_type         = "PercentChangeInCapacity"
    cooldown                = var.braintrust_api_ingest_event_loop_delay_autoscaling.cooldown
    metric_aggregation_type = "Average"

    dynamic "step_adjustment" {
      for_each = local.event_loop_delay_step_adjustments[local.braintrust_api_ingest_name]
      content {
        metric_interval_lower_bound = step_adjustment.value.lower_bound
        metric_interval_upper_bound = step_adjustment.value.upper_bound
        scaling_adjustment          = step_adjustment.value.scaling_adjustment
      }
    }
  }
}

resource "aws_cloudwatch_metric_alarm" "braintrust_api_ingest_event_loop_delay_high" {
  alarm_name          = "${var.deployment_name}-braintrust-api-ingest-event-loop-delay-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.braintrust_api_ingest_event_loop_delay_autoscaling.evaluation_periods
  metric_name         = "EventLoopDelayMeanMs"
  namespace           = "Braintrust/Api"
  period              = var.braintrust_api_ingest_event_loop_delay_autoscaling.period
  statistic           = "Average"
  threshold           = local.event_loop_delay_alarm_thresholds[local.braintrust_api_ingest_name]
  treat_missing_data  = "notBreaching"
  alarm_description   = "Scale out braintrust-api-ingest when EventLoopDelayMeanMs exceeds ${local.event_loop_delay_alarm_thresholds[local.braintrust_api_ingest_name]}ms."
  alarm_actions       = [aws_appautoscaling_policy.braintrust_api_ingest_event_loop_delay_step.arn]

  dimensions = {
    DeploymentName = var.deployment_name
    ServiceName    = local.braintrust_api_ingest_name
  }

  tags = merge({
    Name = "${var.deployment_name}-braintrust-api-ingest-event-loop-delay-high"
  }, local.common_tags)
}
