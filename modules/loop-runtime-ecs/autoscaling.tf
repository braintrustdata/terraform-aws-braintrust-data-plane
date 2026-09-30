resource "aws_appautoscaling_target" "loop_runtime" {
  max_capacity       = var.max_capacity
  min_capacity       = var.min_capacity
  resource_id        = "service/${var.ecs_cluster_name}/${aws_ecs_service.loop_runtime.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

# Runtime emits this every 15 seconds, including during model calls.
resource "aws_appautoscaling_policy" "loop_runtime_conversation_target" {
  name               = "${var.deployment_name}-loop-runtime-conversation-target"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.loop_runtime.resource_id
  scalable_dimension = aws_appautoscaling_target.loop_runtime.scalable_dimension
  service_namespace  = aws_appautoscaling_target.loop_runtime.service_namespace

  target_tracking_scaling_policy_configuration {
    customized_metric_specification {
      namespace   = local.capacity_metric_namespace
      metric_name = "ClaimedConversationUtilization"
      statistic   = "Average"
      unit        = "Percent"

      dimensions {
        name  = "ClusterName"
        value = var.ecs_cluster_name
      }

      dimensions {
        name  = "ServiceName"
        value = local.service_name
      }
    }

    target_value       = var.target_conversation_utilization
    scale_in_cooldown  = 120
    scale_out_cooldown = 60
  }
}
