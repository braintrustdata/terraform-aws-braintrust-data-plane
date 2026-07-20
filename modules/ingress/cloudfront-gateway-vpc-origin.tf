locals {
  cloudfront_PrivateGatewayOrigin = "PrivateGatewayOrigin"
  # Use the boolean flag only — do not gate on gateway_alb_arn/dns (unknown at
  # plan on greenfield create_vpc applies). use_private_ai_gateway_origin already
  # requires create_ai_gateway, so the ALB module is always present when this is true.
  enable_private_gateway_cloudfront_origin = var.use_private_ai_gateway_origin
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
    # Post-apply ALB subnet fingerprint — see api_ecs VPC origin for rationale.
    AlbSubnetsApplied = var.gateway_alb_subnets_applied
  }, local.common_tags)
}
