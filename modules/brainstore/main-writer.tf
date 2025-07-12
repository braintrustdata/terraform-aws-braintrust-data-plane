
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
    aws_region                             = data.aws_region.current.name
    deployment_name                        = var.deployment_name
    database_secret_arn                    = var.database_secret_arn
    database_host                          = var.database_host
    database_port                          = var.database_port
    redis_host                             = var.redis_host
    redis_port                             = var.redis_port
    brainstore_port                        = var.port
    brainstore_s3_bucket                   = aws_s3_bucket.brainstore.id
    brainstore_license_key                 = var.license_key
    brainstore_version_override            = var.version_override == null ? "" : var.version_override
    brainstore_release_version             = local.brainstore_release_version
    brainstore_disable_optimization_worker = var.brainstore_disable_optimization_worker
    brainstore_vacuum_all_objects          = var.brainstore_vacuum_all_objects
    is_dedicated_writer_node               = "true"
    extra_env_vars                         = var.extra_env_vars_writer
    internal_observability_api_key         = var.internal_observability_api_key
    internal_observability_env_name        = var.internal_observability_env_name
    internal_observability_region          = var.internal_observability_region
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
  count              = local.has_writer_nodes ? 1 : 0
  name               = "${var.deployment_name}-bstr-w"
  internal           = true
  load_balancer_type = "network"
  subnets            = var.private_subnet_ids
  security_groups    = [aws_security_group.brainstore_elb.id]

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

resource "aws_autoscaling_group" "brainstore_writer" {
  count                     = local.has_writer_nodes ? 1 : 0
  name_prefix               = "${var.deployment_name}-brainstore-writer"
  min_size                  = var.writer_instance_count
  max_size                  = var.writer_instance_count * 2
  desired_capacity          = var.writer_instance_count
  vpc_zone_identifier       = var.private_subnet_ids
  health_check_type         = "EBS,ELB"
  health_check_grace_period = 60
  target_group_arns         = [aws_lb_target_group.brainstore_writer[0].arn]
  wait_for_elb_capacity     = var.writer_instance_count
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
