locals {
  brainstore_release_version = jsondecode(file("${path.module}/VERSIONS.json"))["brainstore"]
  common_tags = {
    BraintrustDeploymentName = var.deployment_name
  }
  architecture     = data.aws_ec2_instance_type.brainstore.supported_architectures[0]
  has_writer_nodes = var.writer_instance_count > 0
}

resource "aws_launch_template" "brainstore" {
  name                   = "${var.deployment_name}-brainstore"
  image_id               = data.aws_ami.ubuntu_24_04.id
  instance_type          = var.instance_type
  key_name               = var.instance_key_pair_name
  update_default_version = true

  iam_instance_profile {
    arn = aws_iam_instance_profile.brainstore.arn
  }

  vpc_security_group_ids = [aws_security_group.brainstore_instance.id]

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

  user_data = base64encode(templatefile("${path.module}/templates/user_data.sh.tpl", {
    aws_region                  = data.aws_region.current.name
    deployment_name             = var.deployment_name
    database_secret_arn         = var.database_secret_arn
    database_host               = var.database_host
    database_port               = var.database_port
    redis_host                  = var.redis_host
    redis_port                  = var.redis_port
    brainstore_port             = var.port
    brainstore_s3_bucket        = aws_s3_bucket.brainstore.id
    brainstore_license_key      = var.license_key
    brainstore_version_override = var.version_override == null ? "" : var.version_override
    brainstore_release_version  = local.brainstore_release_version
    monitoring_telemetry        = var.monitoring_telemetry
    # Important note: if there are no dedicated writer nodes, this node serves as a read/writer node
    brainstore_disable_optimization_worker = local.has_writer_nodes ? true : var.brainstore_disable_optimization_worker
    brainstore_disable_vacuum              = local.has_writer_nodes ? true : false
    is_dedicated_writer_node               = "false"
    extra_env_vars                         = var.extra_env_vars
    internal_observability_api_key         = var.internal_observability_api_key
    internal_observability_env_name        = var.internal_observability_env_name
    internal_observability_region          = var.internal_observability_region
  }))

  tags = merge({
    Name = "${var.deployment_name}-brainstore"
  }, local.common_tags)

  tag_specifications {
    resource_type = "instance"
    tags = merge({
      Name           = local.has_writer_nodes ? "${var.deployment_name}-brainstore-reader" : "${var.deployment_name}-brainstore"
      BrainstoreRole = local.has_writer_nodes ? "Reader" : "ReaderWriter"
    }, local.common_tags)
  }

  tag_specifications {
    resource_type = "volume"
    tags = merge({
      Name           = local.has_writer_nodes ? "${var.deployment_name}-brainstore-reader" : "${var.deployment_name}-brainstore"
      BrainstoreRole = local.has_writer_nodes ? "Reader" : "ReaderWriter"
    }, local.common_tags)
  }

  tag_specifications {
    resource_type = "network-interface"
    tags = merge({
      Name           = local.has_writer_nodes ? "${var.deployment_name}-brainstore-reader" : "${var.deployment_name}-brainstore"
      BrainstoreRole = local.has_writer_nodes ? "Reader" : "ReaderWriter"
    }, local.common_tags)
  }
}

resource "aws_lb" "brainstore" {
  name               = "${var.deployment_name}-brainstore"
  internal           = true
  load_balancer_type = "network"
  subnets            = var.private_subnet_ids
  security_groups    = [aws_security_group.brainstore_elb.id]

  lifecycle {
    # Changing security groups requires a new NLB.
    create_before_destroy = true
  }

  tags = local.common_tags
}

resource "aws_lb_target_group" "brainstore" {
  name        = "${var.deployment_name}-brainstore"
  port        = var.port
  protocol    = "TCP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    protocol            = "TCP"
    port                = var.port
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 10
    interval            = 10
  }

  tags = local.common_tags
}

resource "aws_lb_listener" "brainstore" {
  load_balancer_arn = aws_lb.brainstore.arn
  port              = var.port
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.brainstore.arn
  }
  tags = local.common_tags
}

resource "aws_autoscaling_group" "brainstore" {
  name_prefix         = "${var.deployment_name}-brainstore"
  min_size            = var.enable_autoscaling ? var.autoscaling_min_capacity : var.instance_count
  max_size            = var.enable_autoscaling ? var.autoscaling_max_capacity : var.instance_count * 2
  desired_capacity    = var.enable_autoscaling ? var.autoscaling_desired_capacity : var.instance_count
  vpc_zone_identifier = var.private_subnet_ids
  health_check_type   = "EBS,ELB"
  # This is essentially the expected boot and setup time of the instance.
  # If too low, the ASG may terminate the instance before it has a chance to boot.
  health_check_grace_period = 60
  target_group_arns         = [aws_lb_target_group.brainstore.arn]
  wait_for_elb_capacity     = var.enable_autoscaling ? var.autoscaling_desired_capacity : var.instance_count
  launch_template {
    id      = aws_launch_template.brainstore.id
    version = aws_launch_template.brainstore.latest_version
  }

  lifecycle {
    # If this ever has to be replaced, we want a new ASG to be created before the old one is terminated.
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
    value               = local.has_writer_nodes ? "${var.deployment_name}-brainstore-reader" : "${var.deployment_name}-brainstore"
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

# CloudWatch Alarms for CPU-based autoscaling
resource "aws_cloudwatch_metric_alarm" "brainstore_cpu_high" {
  count               = var.enable_autoscaling ? 1 : 0
  alarm_name          = "Autoscaling/${var.deployment_name}-brainstore/CPUUtilization/High"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.autoscaling_cpu_evaluation_periods
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = var.autoscaling_cpu_period
  statistic           = "Average"
  threshold           = var.autoscaling_cpu_scale_up_threshold
  alarm_description   = "This metric monitors brainstore cpu utilization for scale up"
  alarm_actions       = [aws_autoscaling_policy.brainstore_scale_up[0].arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.brainstore.name
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "brainstore_cpu_low" {
  count               = var.enable_autoscaling ? 1 : 0
  alarm_name          = "Autoscaling/${var.deployment_name}-brainstore/CPUUtilization/Low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = var.autoscaling_cpu_evaluation_periods
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = var.autoscaling_cpu_period
  statistic           = "Average"
  threshold           = var.autoscaling_cpu_scale_down_threshold
  alarm_description   = "This metric monitors brainstore cpu utilization for scale down"
  alarm_actions       = [aws_autoscaling_policy.brainstore_scale_down[0].arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.brainstore.name
  }

  tags = local.common_tags
}

# Autoscaling Policies - Step Scaling
resource "aws_autoscaling_policy" "brainstore_scale_up" {
  count                     = var.enable_autoscaling ? 1 : 0
  name                      = "${var.deployment_name}-brainstore-scale-up"
  adjustment_type           = var.autoscaling_adjustment_type
  autoscaling_group_name    = aws_autoscaling_group.brainstore.name
  policy_type               = "StepScaling"
  estimated_instance_warmup = 300

  dynamic "step_adjustment" {
    for_each = var.autoscaling_step_scaling_up
    content {
      metric_interval_lower_bound = step_adjustment.value.metric_interval_lower_bound
      metric_interval_upper_bound = step_adjustment.value.metric_interval_upper_bound
      scaling_adjustment          = step_adjustment.value.scaling_adjustment
    }
  }
}

resource "aws_autoscaling_policy" "brainstore_scale_down" {
  count                     = var.enable_autoscaling ? 1 : 0
  name                      = "${var.deployment_name}-brainstore-scale-down"
  adjustment_type           = var.autoscaling_adjustment_type
  autoscaling_group_name    = aws_autoscaling_group.brainstore.name
  policy_type               = "StepScaling"
  estimated_instance_warmup = 300

  dynamic "step_adjustment" {
    for_each = var.autoscaling_step_scaling_down
    content {
      metric_interval_lower_bound = step_adjustment.value.metric_interval_lower_bound
      metric_interval_upper_bound = step_adjustment.value.metric_interval_upper_bound
      scaling_adjustment          = step_adjustment.value.scaling_adjustment
    }
  }
}

data "aws_ami" "ubuntu_24_04" {
  most_recent = true

  # Canonical's AWS account for official Ubuntu images.
  owners = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-*-24.04-*-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  filter {
    name   = "architecture"
    values = [local.architecture]
  }
}

data "aws_ec2_instance_type" "brainstore" {
  instance_type = var.instance_type
}

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}
