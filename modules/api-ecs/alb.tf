resource "aws_security_group" "alb" {
  name        = "${var.deployment_name}-api-ecs-alb"
  description = "Security group for API ECS ALB"
  vpc_id      = var.vpc_id
  tags = merge({
    Name = "${var.deployment_name}-api-ecs-alb"
  }, local.common_tags)
}

resource "aws_security_group_rule" "alb_ingress_http_from_authorized_security_groups" {
  for_each = var.authorized_security_groups

  type                     = "ingress"
  from_port                = local.alb_listener_port
  to_port                  = local.alb_listener_port
  protocol                 = "tcp"
  source_security_group_id = each.value
  description              = "Allow inbound traffic from ${each.key}."
  security_group_id        = aws_security_group.alb.id
}

resource "aws_security_group_rule" "alb_ingress_http_from_authorized_cidr_blocks" {
  for_each = toset(var.authorized_cidr_blocks)

  type              = "ingress"
  from_port         = local.alb_listener_port
  to_port           = local.alb_listener_port
  protocol          = "tcp"
  cidr_blocks       = [each.value]
  description       = "Allow inbound traffic from authorized CIDR ${each.value}."
  security_group_id = aws_security_group.alb.id
}

# Keep the existing rule addresses and types for live deployments.
resource "aws_vpc_security_group_ingress_rule" "alb_ingress_from_gateway" {
  for_each = var.gateway_security_groups

  security_group_id            = aws_security_group.alb.id
  referenced_security_group_id = each.value
  from_port                    = var.enable_private_dataplane ? 8000 : local.alb_listener_port
  to_port                      = var.enable_private_dataplane ? 8000 : local.alb_listener_port
  ip_protocol                  = "tcp"
  description                  = "Allow inbound traffic from ${each.key}."
  tags                         = local.common_tags
}

data "aws_ec2_managed_prefix_list" "cloudfront_origin_facing" {
  count = var.enable_private_dataplane ? 0 : 1

  name = "com.amazonaws.global.cloudfront.origin-facing"
}

resource "aws_vpc_security_group_ingress_rule" "alb_ingress_http_from_cloudfront" {
  count = var.enable_private_dataplane ? 0 : 1

  security_group_id = aws_security_group.alb.id
  prefix_list_id    = data.aws_ec2_managed_prefix_list.cloudfront_origin_facing[0].id
  from_port         = local.alb_listener_port
  to_port           = local.alb_listener_port
  ip_protocol       = "tcp"
  description       = "Allow inbound traffic from CloudFront VPC origins."
}

resource "aws_vpc_security_group_ingress_rule" "alb_ingress_http_from_internal_security_groups" {
  for_each = var.enable_private_dataplane ? var.internal_authorized_security_groups : {}

  security_group_id            = aws_security_group.alb.id
  referenced_security_group_id = each.value
  from_port                    = 8000
  to_port                      = 8000
  ip_protocol                  = "tcp"
  description                  = "Allow internal API requests from ${each.key}."

  tags = merge({
    Name = "${var.deployment_name}-api-internal-${each.key}"
  }, local.common_tags)
}

# Loop starts after the gateway. Baseline callback access must not wait for Loop.
resource "aws_vpc_security_group_ingress_rule" "alb_ingress_http_from_loop_runtime" {
  for_each = var.enable_private_dataplane ? var.loop_runtime_security_groups : {}

  security_group_id            = aws_security_group.alb.id
  referenced_security_group_id = each.value
  from_port                    = 8000
  to_port                      = 8000
  ip_protocol                  = "tcp"
  description                  = "Allow internal API requests from ${each.key}."

  tags = merge({
    Name = "${var.deployment_name}-api-internal-${each.key}"
  }, local.common_tags)
}

resource "aws_security_group_rule" "alb_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow all outbound traffic from API ECS ALB."
  security_group_id = aws_security_group.alb.id
}

resource "aws_security_group_rule" "task_ingress_from_alb" {
  type                     = "ingress"
  from_port                = 8000
  to_port                  = 8000
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb.id
  description              = "Allow inbound traffic from API ECS ALB to API ECS tasks."
  security_group_id        = var.task_security_group_id
}

resource "aws_lb" "api_ecs" {
  name               = "${var.deployment_name}-api-ecs"
  internal           = true
  load_balancer_type = "application"
  subnets            = var.private_subnet_ids
  security_groups    = [aws_security_group.alb.id]

  idle_timeout                     = 900
  client_keep_alive                = 3600
  enable_deletion_protection       = false
  enable_http2                     = true
  desync_mitigation_mode           = "defensive"
  enable_cross_zone_load_balancing = true
  drop_invalid_header_fields       = var.alb_drop_invalid_header_fields

  tags = merge({
    Name = "${var.deployment_name}-api-ecs"
  }, local.common_tags)
}

resource "aws_lb_target_group" "braintrust_api" {
  name        = "${var.deployment_name}-api"
  port        = 8000
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.vpc_id

  deregistration_delay = var.target_group_deregistration_delay_seconds

  health_check {
    path                = "/"
    matcher             = "200-399"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 10
  }

  tags = merge({
    Name = "${var.deployment_name}-braintrust-api"
  }, local.common_tags)
}

resource "aws_lb_target_group" "braintrust_api_ingest" {
  name        = "${var.deployment_name}-api-ingest"
  port        = 8000
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.vpc_id

  deregistration_delay = var.target_group_deregistration_delay_seconds

  health_check {
    path                = "/"
    matcher             = "200-399"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 10
  }

  tags = merge({
    Name = "${var.deployment_name}-braintrust-api-ingest"
  }, local.common_tags)
}

resource "aws_lb_target_group" "braintrust_api_background" {
  name        = "${var.deployment_name}-api-bg"
  port        = 8000
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.vpc_id

  deregistration_delay = var.target_group_deregistration_delay_seconds

  health_check {
    path                = "/"
    matcher             = "200-399"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 10
  }

  tags = merge({
    Name = "${var.deployment_name}-braintrust-api-background"
  }, local.common_tags)
}

resource "aws_lb_listener" "api_ecs_http" {
  load_balancer_arn = aws_lb.api_ecs.arn
  port              = local.alb_listener_port
  protocol          = local.alb_https_enabled ? "HTTPS" : "HTTP"

  # This must be a policy that support TLS 1.2 since Cloudfront does not support TLS 1.3 for origins yet.
  ssl_policy      = local.alb_https_enabled ? "ELBSecurityPolicy-TLS13-1-2-2021-06" : null
  certificate_arn = local.alb_https_enabled ? var.alb_certificate_arn : null

  # Unmatched traffic goes to braintrust-api. Ingest/background traffic is routed
  # by the path rules in alb-path-routes.tf.
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.braintrust_api.arn
  }
}

resource "aws_lb_listener" "api_ecs_internal" {
  count = var.enable_private_dataplane ? 1 : 0

  load_balancer_arn = aws_lb.api_ecs.arn
  port              = 8000
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.braintrust_api.arn
  }

  tags = local.common_tags
}

resource "aws_ssm_parameter" "api_url" {
  name        = "/braintrust/${var.deployment_name}/ecs-api-url"
  type        = "String"
  value       = var.enable_private_dataplane ? local.internal_api_url : local.api_ecs_url
  description = "API ECS URL for Brainstore"

  tags = local.common_tags

  depends_on = [
    aws_lb_listener.api_ecs_internal,
    aws_lb_listener_rule.alb_internal_path_routes,
    aws_vpc_security_group_ingress_rule.alb_ingress_http_from_internal_security_groups,
  ]
}
