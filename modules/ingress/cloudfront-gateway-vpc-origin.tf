locals {
  cloudfront_PrivateGatewayOrigin          = "PrivateGatewayOrigin"
  enable_private_gateway_cloudfront_origin = var.use_private_ai_gateway_origin && var.gateway_alb_arn != null && var.gateway_alb_dns_name != null
}

resource "aws_cloudfront_vpc_origin" "gateway" {
  count = local.enable_private_gateway_cloudfront_origin ? 1 : 0

  vpc_origin_endpoint_config {
    name                   = "${var.deployment_name}-gateway"
    arn                    = var.gateway_alb_arn
    http_port              = 80
    https_port             = 443
    origin_protocol_policy = "http-only"

    origin_ssl_protocols {
      items    = ["TLSv1.2"]
      quantity = 1
    }
  }

  tags = merge({
    CloudFrontVpcOriginIngressRuleId = var.gateway_cloudfront_ingress_rule_id
  }, local.common_tags)
}
