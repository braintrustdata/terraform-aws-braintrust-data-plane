data "aws_ec2_managed_prefix_list" "cloudfront_vpc_origin" {
  count = var.enable_cloudfront_vpc_origin_ingress ? 1 : 0

  name = "com.amazonaws.global.cloudfront.origin-facing"
}

resource "aws_vpc_security_group_ingress_rule" "loop_runtime_alb_from_cloudfront_vpc_origin" {
  count = var.enable_cloudfront_vpc_origin_ingress ? 1 : 0

  security_group_id = aws_security_group.loop_runtime_alb.id
  prefix_list_id    = data.aws_ec2_managed_prefix_list.cloudfront_vpc_origin[0].id
  from_port         = local.loop_runtime_container_port
  to_port           = local.loop_runtime_container_port
  ip_protocol       = "tcp"
  description       = "Allow HTTP from CloudFront VPC origins."

  tags = merge({
    Name = "${var.deployment_name}-loop-runtime-alb-cloudfront"
  }, local.common_tags)
}
