data "aws_security_group" "cloudfront_vpc_origins" {
  count = var.allow_cloudfront_origin_facing_traffic ? 1 : 0

  name   = "CloudFront-VPCOrigins-Service-SG"
  vpc_id = var.vpc_id
}

resource "aws_security_group" "alb" {
  name        = "${var.deployment_name}-api-ecs-alb"
  description = "Security group for private API-ECS ALB"
  vpc_id      = var.vpc_id
  tags = merge({
    Name = "${var.deployment_name}-api-ecs-alb"
  }, local.common_tags)
}

resource "aws_security_group" "alb_cloudfront" {
  count = var.allow_cloudfront_origin_facing_traffic ? 1 : 0

  name        = "${var.deployment_name}-api-ecs-alb-cloudfront"
  description = "Security group for CloudFront ingress to private API-ECS ALB"
  vpc_id      = var.vpc_id
  tags = merge({
    Name = "${var.deployment_name}-api-ecs-alb-cloudfront"
  }, local.common_tags)
}

resource "aws_security_group_rule" "alb_ingress_http_from_authorized_security_groups" {
  for_each = var.authorized_security_groups

  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  source_security_group_id = each.value
  description              = "Allow HTTP traffic from ${each.key}."
  security_group_id        = aws_security_group.alb.id
}

resource "aws_security_group_rule" "alb_ingress_http_from_authorized_cidr_blocks" {
  for_each = toset(var.authorized_cidr_blocks)

  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = [each.value]
  description       = "Allow HTTP traffic from authorized CIDR ${each.value}."
  security_group_id = aws_security_group.alb.id
}

resource "aws_security_group_rule" "alb_ingress_https_from_authorized_security_groups" {
  for_each = local.enable_https ? var.authorized_security_groups : {}

  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = each.value
  description              = "Allow HTTPS traffic from ${each.key}."
  security_group_id        = aws_security_group.alb.id
}

resource "aws_security_group_rule" "alb_ingress_https_from_authorized_cidr_blocks" {
  for_each = local.enable_https ? toset(var.authorized_cidr_blocks) : toset([])

  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = [each.value]
  description       = "Allow HTTPS traffic from authorized CIDR ${each.value}."
  security_group_id = aws_security_group.alb.id
}

resource "aws_security_group_rule" "alb_ingress_http_from_cloudfront_origin_facing" {
  count = var.allow_cloudfront_origin_facing_traffic ? 1 : 0

  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  source_security_group_id = data.aws_security_group.cloudfront_vpc_origins[0].id
  description              = "Allow HTTP traffic from CloudFront VPC Origins service SG to private API-ECS ALB."
  security_group_id        = aws_security_group.alb_cloudfront[0].id
}

resource "aws_security_group_rule" "alb_ingress_https_from_cloudfront_origin_facing" {
  count = var.allow_cloudfront_origin_facing_traffic && local.enable_https ? 1 : 0

  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = data.aws_security_group.cloudfront_vpc_origins[0].id
  description              = "Allow HTTPS traffic from CloudFront VPC Origins service SG to private API-ECS ALB."
  security_group_id        = aws_security_group.alb_cloudfront[0].id
}

resource "aws_security_group_rule" "alb_cloudfront_egress_all" {
  count = var.allow_cloudfront_origin_facing_traffic ? 1 : 0

  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow all outbound traffic from API-ECS CloudFront ALB security group"
  security_group_id = aws_security_group.alb_cloudfront[0].id
}

resource "aws_security_group_rule" "alb_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow all outbound traffic from API-ECS ALB"
  security_group_id = aws_security_group.alb.id
}

resource "aws_security_group" "task" {
  name        = "${var.deployment_name}-api-ecs-task"
  description = "Security group for API-ECS tasks"
  vpc_id      = var.vpc_id
  tags = merge({
    Name = "${var.deployment_name}-api-ecs-task"
  }, local.common_tags)
}

resource "aws_security_group_rule" "task_ingress_from_alb" {
  type                     = "ingress"
  from_port                = var.container_port
  to_port                  = var.container_port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb.id
  description              = "Allow inbound traffic from API-ECS ALB to API-ECS tasks"
  security_group_id        = aws_security_group.task.id
}

resource "aws_security_group_rule" "task_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow all outbound traffic from API-ECS tasks"
  security_group_id = aws_security_group.task.id
}
