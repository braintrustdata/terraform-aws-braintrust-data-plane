resource "aws_vpc_security_group_ingress_rule" "gateway_alb_from_quarantine_vpc" {
  count = var.quarantine_vpc_cidr != null ? 1 : 0

  security_group_id = aws_security_group.gateway_alb.id
  cidr_ipv4         = var.quarantine_vpc_cidr
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  description       = "Allow HTTP from quarantine VPC CIDR."

  tags = merge({
    Name = "${var.deployment_name}-gateway-alb-quarantine"
  }, local.common_tags)
}
