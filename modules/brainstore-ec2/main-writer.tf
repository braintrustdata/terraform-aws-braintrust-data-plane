
resource "aws_launch_template" "brainstore_writer" {
  count                  = local.has_writer_nodes ? 1 : 0
  name                   = "${var.deployment_name}-brainstore-writer"
  image_id               = data.aws_ami.ubuntu_24_04.id
  instance_type          = var.writer_instance_type
  key_name               = var.instance_key_pair_name
  update_default_version = true

  iam_instance_profile {
    arn = aws_iam_instance_profile.brainstore.arn
  }

  vpc_security_group_ids = [var.brainstore_instance_security_group_id]

  block_device_mappings {
    device_name = "/dev/sda1"
    ebs {
      volume_size           = 200
      volume_type           = "gp3"
      encrypted             = true
      kms_key_id            = var.kms_key_arn
      delete_on_termination = true
    }
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
    instance_metadata_tags      = "enabled"
  }

  monitoring {
    enabled = true
  }

  user_data = base64gzip(templatefile("${path.module}/templates/user_data.sh.tpl", {
    aws_region                                    = data.aws_region.current.region
    deployment_name                               = var.deployment_name
    database_secret_arn                           = var.database_secret_arn
    database_host                                 = var.database_host
    database_port                                 = var.database_port
    brainstore_port                               = var.port
    brainstore_s3_bucket                          = local.brainstore_s3_bucket_id
    lambda_responses_bucket_id                    = local.lambda_responses_bucket_id
    code_bundle_bucket_id                         = local.code_bundle_bucket_id
    brainstore_locks_s3_path                      = trimprefix(var.locks_s3_path, "/")
    license_key_secret_arn                        = var.license_key_secret_arn
    license_key_secret_version                    = var.license_key_secret_version
    brainstore_version_override                   = var.version_override == null ? "" : var.version_override
    brainstore_release_version                    = local.brainstore_release_version
    cloudwatch_asg_metrics                        = local.writer_autoscaling_enabled
    cloudwatch_statsd_metrics                     = local.writer_autoscaling_enabled
    monitoring_telemetry                          = var.monitoring_telemetry
    is_dedicated_reader_node                      = "false"
    is_dedicated_writer_node                      = "true"
    extra_env_vars                                = merge(local.brainstore_default_env_vars, local.brainstore_writer_extra_env_vars)
    internal_observability_api_key_secret_arn     = var.internal_observability_api_key_secret_arn
    internal_observability_api_key_secret_version = var.internal_observability_api_key_secret_version
    internal_observability_env_name               = var.internal_observability_env_name
    internal_observability_region                 = var.internal_observability_region
    datadog_agent_container_logs                  = module.datadog_agent_telemetry["writer"].container_logs
    datadog_agent_otlp_env_vars                   = module.datadog_agent_telemetry["writer"].otlp_env_vars
    service_token_secret_arn                      = var.service_token_secret_arn
    custom_ca_bundle_secret_arn                   = var.custom_ca_bundle_secret_arn == null ? "" : var.custom_ca_bundle_secret_arn
    custom_post_install_script                    = var.custom_post_install_script
    brainstore_cache_file_size                    = local.brainstore_writer_cache_file_size
    skip_pg_for_brainstore_objects                = var.skip_pg_for_brainstore_objects
    ai_proxy_url_ssm_parameter                    = var.ai_proxy_url_ssm_parameter
    redis_url_secret_arn                          = var.redis_url_secret_arn
    redis_url_secret_version_id                   = var.redis_url_secret_version_id
  }))

  tags = merge({
    Name = "${var.deployment_name}-brainstore-writer"
  }, local.common_tags)

  tag_specifications {
    resource_type = "instance"
    tags = merge({
      Name           = "${var.deployment_name}-brainstore-writer"
      BrainstoreRole = "Writer"
    }, local.common_tags)
  }

  tag_specifications {
    resource_type = "volume"
    tags = merge({
      Name           = "${var.deployment_name}-brainstore-writer"
      BrainstoreRole = "Writer"
    }, local.common_tags)
  }

  tag_specifications {
    resource_type = "network-interface"
    tags = merge({
      Name           = "${var.deployment_name}-brainstore-writer"
      BrainstoreRole = "Writer"
    }, local.common_tags)
  }
}

resource "aws_lb" "brainstore_writer" {
  count                            = local.has_writer_nodes ? 1 : 0
  name                             = "${var.deployment_name}-bstr-w"
  internal                         = true
  load_balancer_type               = "network"
  enable_cross_zone_load_balancing = true
  subnets                          = var.private_subnet_ids
  security_groups                  = [aws_security_group.brainstore_elb.id]

  lifecycle {
    create_before_destroy = true
  }

  tags = local.common_tags
}

resource "aws_lb_target_group" "brainstore_writer" {
  count       = local.has_writer_nodes ? 1 : 0
  name        = "${var.deployment_name}-bstr-w"
  port        = var.port
  protocol    = "TCP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  connection_termination = true
  deregistration_delay   = 30
  health_check {
    protocol            = "TCP"
    matcher             = ""
    path                = ""
    port                = var.port
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 10
    interval            = 10
  }

  tags = local.common_tags
}

resource "aws_lb_listener" "brainstore_writer" {
  count             = local.has_writer_nodes ? 1 : 0
  load_balancer_arn = aws_lb.brainstore_writer[0].arn
  port              = var.port
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.brainstore_writer[0].arn
  }
  tags = local.common_tags
}

# With writer autoscaling, Terraform leaves desired capacity to target tracking,
# and the launch template publishes ASG-level statsd metrics for those policies.
resource "aws_autoscaling_group" "brainstore_writer" {
  count                     = local.has_writer_nodes ? 1 : 0
  name_prefix               = "${var.deployment_name}-brainstore-writer"
  min_size                  = local.writer_autoscaling_enabled ? var.writer_min_capacity : var.writer_instance_count
  max_size                  = local.writer_autoscaling_enabled ? var.writer_max_capacity : var.writer_instance_count * 2
  desired_capacity          = local.writer_autoscaling_enabled ? null : var.writer_instance_count
  vpc_zone_identifier       = var.private_subnet_ids
  health_check_type         = "EBS,ELB"
  health_check_grace_period = 60
  target_group_arns         = [aws_lb_target_group.brainstore_writer[0].arn]
  wait_for_elb_capacity     = local.writer_autoscaling_enabled ? var.writer_min_capacity : var.writer_instance_count
  launch_template {
    id      = aws_launch_template.brainstore_writer[0].id
    version = aws_launch_template.brainstore_writer[0].latest_version
  }

  lifecycle {
    create_before_destroy = true
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 100
      max_healthy_percentage = 200
    }
    triggers = ["tag"]
  }

  tag {
    key                 = "Name"
    value               = "${var.deployment_name}-brainstore-writer"
    propagate_at_launch = true
  }

  dynamic "tag" {
    for_each = local.common_tags
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }
}

# Matches the CloudFormation writer policies. Either backlog policy can scale
# out; both must agree before scale-in.
resource "aws_autoscaling_policy" "brainstore_writer_compaction_queue_target" {
  count                  = local.writer_autoscaling_enabled ? 1 : 0
  name                   = "${var.deployment_name}-brainstore-writer-compaction-queue-target"
  autoscaling_group_name = aws_autoscaling_group.brainstore_writer[0].name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    customized_metric_specification {
      # The CloudWatch agent publishes statsd metrics to its default namespace.
      namespace   = "CWAgent"
      metric_name = "brainstore_backfill_compaction_queue_size"
      statistic   = "Average"

      metric_dimension {
        name  = "AutoScalingGroupName"
        value = aws_autoscaling_group.brainstore_writer[0].name
      }
    }

    target_value     = var.writer_target_compaction_queue_size
    disable_scale_in = false
  }
}

resource "aws_autoscaling_policy" "brainstore_writer_merge_loop_segments_target" {
  count                  = local.writer_autoscaling_enabled ? 1 : 0
  name                   = "${var.deployment_name}-brainstore-writer-merge-loop-segments-target"
  autoscaling_group_name = aws_autoscaling_group.brainstore_writer[0].name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    customized_metric_specification {
      namespace   = "CWAgent"
      metric_name = "brainstore_backfill_merge_loop_segments"
      statistic   = "Average"

      metric_dimension {
        name  = "AutoScalingGroupName"
        value = aws_autoscaling_group.brainstore_writer[0].name
      }
    }

    target_value     = var.writer_target_merge_loop_segments
    disable_scale_in = false
  }
}
