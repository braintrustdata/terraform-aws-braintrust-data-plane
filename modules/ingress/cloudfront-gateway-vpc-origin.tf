locals {
  cloudfront_PrivateGatewayOrigin = "PrivateGatewayOrigin"
  # Use the boolean flag only — do not gate on gateway_alb_arn/dns (unknown at
  # plan on greenfield create_vpc applies). Lifetime follows the gateway ALB,
  # not the /v1/proxy routing choice, so switching gateways never deletes an
  # origin that the same apply detaches.
  create_private_gateway_cloudfront_origin = var.create_gateway_vpc_origin
}

resource "aws_cloudfront_vpc_origin" "gateway" {
  count = local.create_private_gateway_cloudfront_origin ? 1 : 0

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
