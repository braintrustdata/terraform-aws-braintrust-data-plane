resource "aws_security_group" "brainstore_elb" {
  name   = var.instance_name_suffix != "" ? "${var.deployment_name}-brainstore-elb-${var.instance_name_suffix}" : "${var.deployment_name}-brainstore-elb"
  vpc_id = var.vpc_id
  tags   = merge({ "Name" = var.instance_name_suffix != "" ? "${var.deployment_name}-brainstore-elb-${var.instance_name_suffix}" : "${var.deployment_name}-brainstore-elb" }, local.common_tags)
}

resource "aws_vpc_security_group_ingress_rule" "brainstore_elb_allow_ingress_from_authorized_security_groups" {
  for_each = var.authorized_security_groups

  from_port                    = var.port
  to_port                      = var.port
  ip_protocol                  = "tcp"
  referenced_security_group_id = each.value
  description                  = "Allow inbound to brainstore from ${each.key}."
  security_group_id            = aws_security_group.brainstore_elb.id
  tags                         = local.common_tags
}

resource "aws_vpc_security_group_egress_rule" "brainstore_elb_allow_egress_all" {
  from_port         = -1
  to_port           = -1
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
  description       = "Allow all outbound traffic from Brainstore ELB."
  security_group_id = aws_security_group.brainstore_elb.id
  tags              = local.common_tags
}

# Security group rules for the brainstore instance security group (created by services-common)
resource "aws_vpc_security_group_ingress_rule" "brainstore_instance_allow_ingress_from_nlb" {
  from_port                    = var.port
  to_port                      = var.port
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.brainstore_elb.id
  description                  = "Allow inbound to Brainstore instances from NLB."
  security_group_id            = var.brainstore_instance_security_group_id
  tags                         = local.common_tags
}

