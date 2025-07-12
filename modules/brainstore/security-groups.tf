resource "aws_security_group" "brainstore_elb" {
  name   = "${var.deployment_name}-brainstore-elb"
  vpc_id = var.vpc_id
  tags   = merge({ "Name" = "${var.deployment_name}-brainstore-elb" }, local.common_tags)
}

resource "aws_vpc_security_group_ingress_rule" "brainstore_elb_allow_ingress_from_authorized_security_groups" {
  for_each = var.authorized_security_groups

  from_port                    = var.port
  to_port                      = var.port
  ip_protocol                  = "tcp"
  referenced_security_group_id = each.value
  description                  = "Allow inbound to brainstore from ${each.key}."
  security_group_id            = aws_security_group.brainstore_elb.id
}

resource "aws_vpc_security_group_egress_rule" "brainstore_elb_allow_egress_all" {
  from_port         = -1
  to_port           = -1
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
  description       = "Allow all outbound traffic from Brainstore ELB."
  security_group_id = aws_security_group.brainstore_elb.id
}

resource "aws_security_group" "brainstore_instance" {
  name   = "${var.deployment_name}-brainstore-instance"
  vpc_id = var.vpc_id
  tags   = merge({ "Name" = "${var.deployment_name}-brainstore-instance" }, local.common_tags)
}

resource "aws_vpc_security_group_ingress_rule" "brainstore_instance_allow_ingress_from_nlb" {

  from_port                    = var.port
  to_port                      = var.port
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.brainstore_elb.id
  description                  = "Allow inbound to Brainstore instances from NLB."
  security_group_id            = aws_security_group.brainstore_instance.id
}

resource "aws_vpc_security_group_ingress_rule" "brainstore_instance_allow_ingress_from_authorized_security_groups_ssh" {
  for_each = var.authorized_security_groups_ssh

  from_port                    = 22
  to_port                      = 22
  ip_protocol                  = "tcp"
  referenced_security_group_id = each.value
  description                  = "Allow inbound SSH to Brainstore instances from ${each.key}."

  security_group_id = aws_security_group.brainstore_instance.id
}

resource "aws_vpc_security_group_egress_rule" "brainstore_instance_allow_egress_all" {

  from_port         = -1
  to_port           = -1
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
  description       = "Allow all outbound traffic from Brainstore instances."
  security_group_id = aws_security_group.brainstore_instance.id
}
