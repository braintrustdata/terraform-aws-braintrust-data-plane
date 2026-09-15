# CPU-based target-tracking autoscaling for the reader and fast reader ASGs.
#
# These policies let AWS Auto Scaling adjust the desired capacity within the
# ASG's [min_size, max_size] range to keep average CPU near the target. The
# corresponding ASGs set desired_capacity = null when autoscaling is enabled
# (see locals in main.tf) so Terraform does not reset the policy's decisions on
# every apply. Writers are intentionally excluded.

resource "aws_autoscaling_policy" "brainstore_reader_cpu" {
  count = local.reader_cpu_autoscaling ? 1 : 0

  name                      = "${var.deployment_name}-brainstore-reader-cpu"
  autoscaling_group_name    = aws_autoscaling_group.brainstore.name
  policy_type               = "TargetTrackingScaling"
  estimated_instance_warmup = var.cpu_autoscaling_estimated_warmup_seconds

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = var.cpu_autoscaling_target_percent
  }
}

resource "aws_autoscaling_policy" "brainstore_fast_reader_cpu" {
  count = local.fast_reader_cpu_autoscaling ? 1 : 0

  name                      = "${var.deployment_name}-brainstore-fast-reader-cpu"
  autoscaling_group_name    = aws_autoscaling_group.brainstore_fast_reader[0].name
  policy_type               = "TargetTrackingScaling"
  estimated_instance_warmup = var.fast_reader_cpu_autoscaling_estimated_warmup_seconds

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = var.fast_reader_cpu_autoscaling_target_percent
  }
}
