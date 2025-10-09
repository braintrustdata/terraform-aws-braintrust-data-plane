resource "aws_security_group" "quarantine_lambda" {
  count  = var.use_quarantine_vpc ? 1 : 0
  name   = "${var.deployment_name}-quarantine-lambda"
  vpc_id = var.quarantine_vpc_id
  tags   = merge({ "Name" = "${var.deployment_name}-quarantine-lambda" }, local.common_tags)
}

resource "aws_security_group_rule" "quarantine_lambda_allow_egress_all" {
  count             = var.use_quarantine_vpc ? 1 : 0
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow all outbound traffic from Lambdas."
  security_group_id = aws_security_group.quarantine_lambda[0].id
}
