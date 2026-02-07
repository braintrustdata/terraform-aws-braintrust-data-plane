# At some point in the future this "lambda" security group should be removed
# It is duplicative of the security group in services-common
# but we have to keep it for now to avoid downtime for current customers
resource "aws_security_group" "lambda" {
  name   = "${var.deployment_name}-lambda"
  vpc_id = var.vpc_id
  tags   = merge({ "Name" = "${var.deployment_name}-lambda" }, local.common_tags)
}

resource "aws_security_group_rule" "lambda_allow_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow all outbound traffic from Lambdas."
  security_group_id = aws_security_group.lambda.id
}
