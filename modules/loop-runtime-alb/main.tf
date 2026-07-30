locals {
  common_tags = merge({
    BraintrustDeploymentName = var.deployment_name
  }, var.custom_tags)

  loop_runtime_container_port = 4001
  loop_runtime_alb_subnet_ids = length(var.loop_runtime_alb_subnet_ids) > 0 ? var.loop_runtime_alb_subnet_ids : var.private_subnet_ids
}

resource "aws_security_group" "loop_runtime_alb" {
  name        = "${var.deployment_name}-loop-runtime-alb"
  description = "Security group for private Loop runtime ALB"
  vpc_id      = var.vpc_id
  tags = merge({
    Name = "${var.deployment_name}-loop-runtime-alb"
  }, local.common_tags)
}

resource "aws_security_group_rule" "loop_runtime_alb_ingress_from_authorized_security_groups" {
  for_each = var.authorized_security_groups

  type                     = "ingress"
  from_port                = local.loop_runtime_container_port
  to_port                  = local.loop_runtime_container_port
  protocol                 = "tcp"
  source_security_group_id = each.value
  description              = "Allow HTTP traffic from ${each.key}."
  security_group_id        = aws_security_group.loop_runtime_alb.id
}

resource "aws_security_group_rule" "loop_runtime_alb_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow all outbound traffic from Loop runtime ALB"
  security_group_id = aws_security_group.loop_runtime_alb.id
}

resource "aws_lb" "loop_runtime" {
  name               = "${var.deployment_name}-loop-runtime"
  internal           = true
  load_balancer_type = "application"
  subnets            = local.loop_runtime_alb_subnet_ids
  security_groups    = [aws_security_group.loop_runtime_alb.id]

  client_keep_alive          = var.alb_client_keep_alive
  idle_timeout               = var.alb_idle_timeout
  drop_invalid_header_fields = var.alb_drop_invalid_header_fields

  tags = merge({
    Name = "${var.deployment_name}-loop-runtime"
  }, local.common_tags)
}

resource "aws_lb_target_group" "loop_runtime" {
  name        = "${var.deployment_name}-loop-runtime"
  port        = local.loop_runtime_container_port
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.vpc_id

  deregistration_delay = var.alb_deregistration_delay

  health_check {
    path                = "/health/liveness"
    matcher             = "200-399"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 10
  }

  tags = merge({
    Name = "${var.deployment_name}-loop-runtime"
  }, local.common_tags)
}

resource "aws_lb_listener" "loop_runtime_http" {
  load_balancer_arn = aws_lb.loop_runtime.arn
  port              = local.loop_runtime_container_port
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.loop_runtime.arn
  }
}
