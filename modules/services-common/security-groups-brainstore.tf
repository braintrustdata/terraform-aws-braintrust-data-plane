resource "aws_security_group" "brainstore_instance" {
  name   = "${var.deployment_name}-brainstore-instance"
  vpc_id = var.vpc_id
  tags   = merge({ "Name" = "${var.deployment_name}-brainstore-instance" }, local.common_tags)
}

resource "aws_vpc_security_group_egress_rule" "brainstore_instance_allow_egress_all" {
  from_port         = -1
  to_port           = -1
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
  description       = "Allow all outbound traffic from Brainstore instances."
  security_group_id = aws_security_group.brainstore_instance.id
}

