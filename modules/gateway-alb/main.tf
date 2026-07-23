locals {
  common_tags = merge({
    BraintrustDeploymentName = var.deployment_name
  }, var.custom_tags)

  gateway_container_port = 8080
  gateway_alb_subnet_ids = length(var.gateway_alb_subnet_ids) > 0 ? var.gateway_alb_subnet_ids : var.private_subnet_ids
}

resource "aws_security_group" "gateway_alb" {
  name        = "${var.deployment_name}-gateway-alb"
  description = "Security group for private gateway ALB"
  vpc_id      = var.vpc_id
  tags = merge({
    Name = "${var.deployment_name}-gateway-alb"
  }, local.common_tags)
}

resource "aws_security_group_rule" "gateway_alb_ingress_from_authorized_security_groups" {
  for_each = var.authorized_security_groups

  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  source_security_group_id = each.value
  description              = "Allow HTTP traffic from ${each.key}."
  security_group_id        = aws_security_group.gateway_alb.id
}

resource "aws_security_group_rule" "gateway_alb_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow all outbound traffic from gateway ALB"
  security_group_id = aws_security_group.gateway_alb.id
}

resource "aws_lb" "gateway" {
  name               = "${var.deployment_name}-gateway"
  internal           = true
  load_balancer_type = "application"
  subnets            = local.gateway_alb_subnet_ids
  security_groups    = [aws_security_group.gateway_alb.id]

  client_keep_alive          = var.alb_client_keep_alive
  idle_timeout               = var.alb_idle_timeout
  drop_invalid_header_fields = var.alb_drop_invalid_header_fields

  tags = merge({
    Name = "${var.deployment_name}-gateway"
  }, local.common_tags)
}

resource "aws_lb_target_group" "gateway" {
  name        = "${var.deployment_name}-gateway"
  port        = local.gateway_container_port
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.vpc_id

  deregistration_delay = var.alb_deregistration_delay

  health_check {
    path                = "/health"
    matcher             = "200"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 10
  }

  tags = merge({
    Name = "${var.deployment_name}-gateway"
  }, local.common_tags)
}

resource "aws_lb_listener" "gateway_http" {
  load_balancer_arn = aws_lb.gateway.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.gateway.arn
  }
}
