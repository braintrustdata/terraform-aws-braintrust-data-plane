resource "aws_security_group" "task" {
  name        = "${var.deployment_name}-gateway-task"
  description = "Security group for gateway ECS tasks"
  vpc_id      = var.vpc_id
  tags = merge({
    Name = "${var.deployment_name}-gateway-task"
  }, local.common_tags)
}

resource "aws_security_group_rule" "task_ingress_from_alb" {
  type                     = "ingress"
  from_port                = local.container_port
  to_port                  = local.container_port
  protocol                 = "tcp"
  source_security_group_id = var.alb_security_group_id
  description              = "Allow inbound traffic from gateway ALB to gateway tasks"
  security_group_id        = aws_security_group.task.id
}

resource "aws_vpc_security_group_ingress_rule" "task_ingress_from_authorized_security_groups" {
  for_each = var.authorized_security_groups

  security_group_id            = aws_security_group.task.id
  referenced_security_group_id = each.value
  from_port                    = local.container_port
  to_port                      = local.container_port
  ip_protocol                  = "tcp"
  description                  = "Allow inbound traffic from ${each.key}."
  tags                         = local.common_tags
}

resource "aws_security_group_rule" "task_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow all outbound traffic from gateway ECS tasks"
  security_group_id = aws_security_group.task.id
}

resource "aws_vpc_security_group_ingress_rule" "cache_allow_ingress_from_gateway_tasks" {
  from_port                    = var.redis_port
  to_port                      = var.redis_port
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.task.id
  description                  = "Allow inbound traffic from gateway tasks."

  security_group_id = var.redis_security_group_id
  tags              = local.common_tags
}
