data "aws_subnet" "data_plane" {
  for_each = { for index, id in var.data_plane_subnet_ids : tostring(index) => id }
  id       = each.value

  lifecycle {
    postcondition {
      condition     = self.vpc_id == var.vpc_id
      error_message = "The Loop egress gateway subnets must belong to the main data-plane VPC."
    }
  }
}

locals {
  data_plane_subnets = values(data.aws_subnet.data_plane)
  data_plane_azs     = [for subnet in local.data_plane_subnets : subnet.availability_zone]
  egress_gateway_subnet_ids = [
    for az in distinct(local.data_plane_azs) : local.data_plane_subnets[index(local.data_plane_azs, az)].id
  ]
}

resource "aws_security_group" "egress_gateway" {
  name        = "${var.deployment_name}-sandbox-egress"
  description = "Sandbox Service access to Loop's private forward proxy"
  vpc_id      = var.vpc_id
  tags        = local.common_tags
}

resource "aws_vpc_security_group_ingress_rule" "egress_gateway_from_workers" {
  security_group_id            = aws_security_group.egress_gateway.id
  referenced_security_group_id = aws_security_group.workers.id
  from_port                    = 4002
  to_port                      = 4002
  ip_protocol                  = "tcp"
  description                  = "Forward proxy connections from sandbox workers"
  tags                         = local.common_tags
}

resource "aws_vpc_security_group_egress_rule" "workers_to_egress_gateway" {
  security_group_id            = aws_security_group.workers.id
  referenced_security_group_id = aws_security_group.egress_gateway.id
  from_port                    = 4002
  to_port                      = 4002
  ip_protocol                  = "tcp"
  description                  = "Private Loop forward proxy"
  tags                         = local.common_tags
}

resource "aws_lb" "egress_gateway" {
  name                             = "${var.deployment_name}-sandbox-eg"
  internal                         = true
  load_balancer_type               = "network"
  subnets                          = local.egress_gateway_subnet_ids
  security_groups                  = [aws_security_group.egress_gateway.id]
  enable_cross_zone_load_balancing = true
  tags                             = local.common_tags
}

resource "aws_lb_target_group" "egress_gateway" {
  name                 = "${var.deployment_name}-sandbox-eg"
  port                 = 4002
  protocol             = "TCP"
  target_type          = "ip"
  vpc_id               = var.vpc_id
  deregistration_delay = 900

  health_check {
    protocol = "TCP"
  }
  tags = local.common_tags
}

resource "aws_lb_listener" "egress_gateway" {
  load_balancer_arn = aws_lb.egress_gateway.arn
  port              = 4002
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.egress_gateway.arn
  }
  tags = local.common_tags
}

output "egress_gateway_dns_name" {
  description = "Private Sandbox Service forward-proxy NLB DNS name."
  value       = aws_lb.egress_gateway.dns_name
}

output "egress_gateway_security_group_id" {
  description = "Forward-proxy NLB source security group for Loop ingress authorization."
  value       = aws_security_group.egress_gateway.id
}

output "egress_gateway_target_group_arn" {
  description = "Forward-proxy target group, available after its listener is attached."
  value       = aws_lb_listener.egress_gateway.default_action[0].target_group_arn
}
