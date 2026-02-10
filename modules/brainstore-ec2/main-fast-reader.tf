
resource "aws_launch_template" "brainstore_fast_reader" {
  count                  = local.has_fast_reader_nodes ? 1 : 0
  name                   = "${var.deployment_name}-brainstore-fast-reader"
  image_id               = data.aws_ami.ubuntu_24_04.id
  instance_type          = var.fast_reader_instance_type
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

  user_data = base64encode(templatefile("${path.module}/templates/user_data.sh.tpl", {
    aws_region                      = data.aws_region.current.region
    deployment_name                 = var.deployment_name
    database_secret_arn             = var.database_secret_arn
    database_host                   = var.database_host
    database_port                   = var.database_port
    redis_host                      = var.redis_host
    redis_port                      = var.redis_port
    brainstore_port                 = var.port
    brainstore_s3_bucket            = local.brainstore_s3_bucket_id
    brainstore_locks_s3_path        = trimprefix(var.locks_s3_path, "/")
    brainstore_license_key          = var.license_key
    brainstore_version_override     = var.version_override == null ? "" : var.version_override
    brainstore_release_version      = local.brainstore_release_version
    monitoring_telemetry            = var.monitoring_telemetry
    is_dedicated_reader_node        = "true"
    is_dedicated_writer_node        = "false"
    extra_env_vars                  = var.extra_env_vars_fast_reader
    internal_observability_api_key  = var.internal_observability_api_key
    internal_observability_env_name = var.internal_observability_env_name
    internal_observability_region   = var.internal_observability_region
    service_token_secret_key        = var.service_token_secret_key
    custom_post_install_script      = var.custom_post_install_script
    brainstore_cache_file_size      = local.brainstore_fast_reader_cache_file_size
  }))

  tags = merge({
    Name = "${var.deployment_name}-brainstore-fast-reader"
  }, local.common_tags)

  tag_specifications {
    resource_type = "instance"
    tags = merge({
      Name           = "${var.deployment_name}-brainstore-fast-reader"
      BrainstoreRole = "FastReader"
    }, local.common_tags)
  }

  tag_specifications {
    resource_type = "volume"
    tags = merge({
      Name           = "${var.deployment_name}-brainstore-fast-reader"
      BrainstoreRole = "FastReader"
    }, local.common_tags)
  }

  tag_specifications {
    resource_type = "network-interface"
    tags = merge({
      Name           = "${var.deployment_name}-brainstore-fast-reader"
      BrainstoreRole = "FastReader"
    }, local.common_tags)
  }
}

resource "aws_lb" "brainstore_fast_reader" {
  count              = local.has_fast_reader_nodes ? 1 : 0
  name               = "${var.deployment_name}-bstr-fr"
  internal           = true
  load_balancer_type = "network"
  subnets            = var.private_subnet_ids
  security_groups    = [aws_security_group.brainstore_elb.id]

  lifecycle {
    create_before_destroy = true
  }

  tags = local.common_tags
}

resource "aws_lb_target_group" "brainstore_fast_reader" {
  count       = local.has_fast_reader_nodes ? 1 : 0
  name        = "${var.deployment_name}-bstr-fr"
  port        = var.port
  protocol    = "TCP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  connection_termination = true
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

resource "aws_lb_listener" "brainstore_fast_reader" {
  count             = local.has_fast_reader_nodes ? 1 : 0
  load_balancer_arn = aws_lb.brainstore_fast_reader[0].arn
  port              = var.port
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.brainstore_fast_reader[0].arn
  }
  tags = local.common_tags
}

resource "aws_autoscaling_group" "brainstore_fast_reader" {
  count                     = local.has_fast_reader_nodes ? 1 : 0
  name_prefix               = "${var.deployment_name}-brainstore-fast-reader"
  min_size                  = var.fast_reader_instance_count
  max_size                  = var.fast_reader_instance_count * 2
  desired_capacity          = var.fast_reader_instance_count
  vpc_zone_identifier       = var.private_subnet_ids
  health_check_type         = "EBS,ELB"
  health_check_grace_period = 60
  target_group_arns         = [aws_lb_target_group.brainstore_fast_reader[0].arn]
  wait_for_elb_capacity     = var.fast_reader_instance_count
  launch_template {
    id      = aws_launch_template.brainstore_fast_reader[0].id
    version = aws_launch_template.brainstore_fast_reader[0].latest_version
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
    value               = "${var.deployment_name}-brainstore-fast-reader"
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
