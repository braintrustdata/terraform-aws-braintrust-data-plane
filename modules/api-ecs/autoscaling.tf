resource "aws_appautoscaling_target" "api_ecs" {
  max_capacity       = var.max_capacity
  min_capacity       = var.min_capacity
  resource_id        = "service/${element(reverse(split("/", var.ecs_cluster_arn)), 0)}/${aws_ecs_service.api_ecs.name}"
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

    target_value       = var.target_cpu_utilization
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

    target_value       = var.target_memory_utilization
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}
