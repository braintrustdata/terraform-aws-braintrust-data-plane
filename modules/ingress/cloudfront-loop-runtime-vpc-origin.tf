resource "aws_cloudfront_vpc_origin" "loop_runtime" {
  count = var.enable_loop_runtime ? 1 : 0

  vpc_origin_endpoint_config {
    name                   = "${var.deployment_name}-loop-runtime"
    arn                    = var.loop_runtime_alb_arn
    http_port              = 4001
    https_port             = 443
    origin_protocol_policy = "http-only"

    origin_ssl_protocols {
      items    = ["TLSv1.2"]
      quantity = 1
    }
  }

  tags = merge({
    CloudFrontVpcOriginIngressRuleId = var.loop_runtime_cloudfront_ingress_rule_id
    AlbSubnetsApplied                = var.loop_runtime_alb_subnets_applied
  }, local.common_tags)
}
