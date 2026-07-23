data "aws_ec2_managed_prefix_list" "cloudfront_vpc_origin" {
  count = var.enable_cloudfront_vpc_origin_ingress ? 1 : 0

  name = "com.amazonaws.global.cloudfront.origin-facing"
}

resource "aws_vpc_security_group_ingress_rule" "gateway_alb_from_cloudfront_vpc_origin" {
  count = var.enable_cloudfront_vpc_origin_ingress ? 1 : 0

  security_group_id = aws_security_group.gateway_alb.id
  prefix_list_id    = data.aws_ec2_managed_prefix_list.cloudfront_vpc_origin[0].id
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  description       = "Allow HTTP from CloudFront VPC origins."

  tags = merge({
    Name = "${var.deployment_name}-gateway-alb-cloudfront"
  }, local.common_tags)
}
