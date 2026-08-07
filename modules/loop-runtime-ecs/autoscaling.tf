resource "aws_appautoscaling_target" "loop_runtime" {
  max_capacity       = var.max_capacity
  min_capacity       = var.min_capacity
  resource_id        = "service/${var.ecs_cluster_name}/${aws_ecs_service.loop_runtime.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "loop_runtime_cpu_target" {
  name               = "${var.deployment_name}-loop-runtime-cpu-target"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.loop_runtime.resource_id
  scalable_dimension = aws_appautoscaling_target.loop_runtime.scalable_dimension
  service_namespace  = aws_appautoscaling_target.loop_runtime.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }

    target_value       = var.target_cpu_utilization
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}

resource "aws_appautoscaling_policy" "loop_runtime_memory_target" {
  name               = "${var.deployment_name}-loop-runtime-memory-target"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.loop_runtime.resource_id
  scalable_dimension = aws_appautoscaling_target.loop_runtime.scalable_dimension
  service_namespace  = aws_appautoscaling_target.loop_runtime.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }

    target_value       = var.target_memory_utilization
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}
