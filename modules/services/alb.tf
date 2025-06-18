locals {
  alb_name = var.deployment_name
}
// Lookup default security group for the VPC
data "aws_security_group" "default" {
  name   = "default"
  vpc_id = var.vpc_id
}

resource "aws_security_group" "api_alb" {
  name   = "${var.deployment_name}-api-alb"
  vpc_id = var.vpc_id
}

// Allow all traffic from the VPC
resource "aws_security_group_rule" "api_alb_allow_http_vpc" {
  security_group_id        = aws_security_group.api_alb.id
  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  source_security_group_id = data.aws_security_group.default.id
}
resource "aws_security_group_rule" "api_alb_allow_https_vpc" {
  security_group_id        = aws_security_group.api_alb.id
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = data.aws_security_group.default.id
}

resource "aws_lb" "api" {
  name               = local.alb_name
  internal           = true
  load_balancer_type = "application"
  security_groups    = [aws_security_group.api_alb.id]
  subnets            = var.service_subnet_ids

  enable_deletion_protection = false

  tags = merge({
    Name = local.alb_name
  }, var.tags)
}

resource "aws_lb_target_group" "api" {
  target_type = "lambda"
  name        = var.deployment_name
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.api.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api.arn
  }
}

resource "aws_lb_target_group_attachment" "api" {
  target_group_arn = aws_lb_target_group.api.arn
  target_id        = aws_lambda_function.api_handler.arn
  port             = 80
}

# Add necessary permissions for ALB to invoke Lambda
resource "aws_lambda_permission" "alb" {
  statement_id  = "AllowALBInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api_handler.function_name
  principal     = "elasticloadbalancing.amazonaws.com"
  source_arn    = aws_lb_target_group.api.arn
}
