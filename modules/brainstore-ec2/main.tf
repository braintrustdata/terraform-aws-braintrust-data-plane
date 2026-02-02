locals {
  brainstore_release_version = jsondecode(file("${path.module}/VERSIONS.json"))["brainstore"]

  # Base tags applied to all resources
  common_tags = merge({
    BraintrustDeploymentName = var.deployment_name
  }, var.custom_tags)

  # Extract bucket ID from ARN (format: arn:aws:s3:::bucket-name)
  brainstore_s3_bucket_id = split(":::", var.brainstore_s3_bucket_arn)[1]

  # Resource name suffix - add dash if suffix is provided
  name_suffix = var.instance_name_suffix != "" ? "-${var.instance_name_suffix}" : ""

  # Determine mode-specific settings (controls actual brainstore behavior)
  is_dedicated_reader_node = var.mode == "reader" ? "true" : "false"
  is_dedicated_writer_node = var.mode == "writer" ? "true" : "false"

  # Get architecture from instance type
  architecture = data.aws_ec2_instance_type.brainstore.supported_architectures[0]

  # Calculate cache file size from ephemeral storage (total_instance_storage is in GB)
  # If total_instance_storage is 0 or null, instances won't have ephemeral storage
  # The user_data script already validates ephemeral device exists, so this should always be > 0 for valid instance types
  # Reduce by 10% to leave buffer space on the disk
  # Use provided override if set, otherwise auto-calculate 90% of ephemeral storage
  brainstore_cache_file_size = var.cache_file_size != null ? var.cache_file_size : "${floor(data.aws_ec2_instance_type.brainstore.total_instance_storage * 0.9)}gb"

  # Determine NLB name using role mapping, unless nlb_name is provided
  # Use lower() to normalize role for lookup (handles both "Reader" and "reader")
  nlb_name = var.nlb_name != null && var.nlb_name != "" ? var.nlb_name : lookup(
    {
      "writer"       = "${var.deployment_name}-bstr-w"
      "reader"       = "${var.deployment_name}-brainstore"
      "readerwriter" = "${var.deployment_name}-brainstore"
    },
    lower(var.role),
    "${var.deployment_name}-bstr-${lower(var.role)}"
  )
}

resource "aws_launch_template" "brainstore" {
  name                   = "${var.deployment_name}-brainstore${local.name_suffix}"
  image_id               = data.aws_ami.ubuntu_24_04.id
  instance_type          = var.instance_type
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
    is_dedicated_reader_node        = local.is_dedicated_reader_node
    is_dedicated_writer_node        = local.is_dedicated_writer_node
    extra_env_vars                  = var.extra_env_vars
    internal_observability_api_key  = var.internal_observability_api_key
    internal_observability_env_name = var.internal_observability_env_name
    internal_observability_region   = var.internal_observability_region
    service_token_secret_key        = var.service_token_secret_key
    custom_post_install_script      = var.custom_post_install_script
    brainstore_cache_file_size      = local.brainstore_cache_file_size
  }))

  tags = merge({
    Name = "${var.deployment_name}-brainstore${local.name_suffix}"
  }, local.common_tags)

  tag_specifications {
    resource_type = "instance"
    tags = merge({
      Name           = "${var.deployment_name}-brainstore${local.name_suffix}"
      BrainstoreRole = var.role
    }, local.common_tags)
  }

  tag_specifications {
    resource_type = "volume"
    tags = merge({
      Name           = "${var.deployment_name}-brainstore${local.name_suffix}"
      BrainstoreRole = var.role
    }, local.common_tags)
  }

  tag_specifications {
    resource_type = "network-interface"
    tags = merge({
      Name           = "${var.deployment_name}-brainstore${local.name_suffix}"
      BrainstoreRole = var.role
    }, local.common_tags)
  }
}

resource "aws_lb" "brainstore" {
  name               = local.nlb_name
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
  name        = local.nlb_name
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
  name_prefix         = "${var.deployment_name}-brainstore${local.name_suffix}"
  min_size            = var.instance_count
  max_size            = var.instance_count * 2
  desired_capacity    = var.instance_count
  vpc_zone_identifier = var.private_subnet_ids
  health_check_type   = "EBS,ELB"
  # This is essentially the expected boot and setup time of the instance.
  # If too low, the ASG may terminate the instance before it has a chance to boot.
  health_check_grace_period = 60
  target_group_arns         = [aws_lb_target_group.brainstore.arn]
  wait_for_elb_capacity     = var.instance_count
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
    value               = "${var.deployment_name}-brainstore${local.name_suffix}"
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
