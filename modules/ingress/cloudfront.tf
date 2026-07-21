locals {
  # https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/using-managed-cache-policies.html#managed-cache-policy-caching-disabled
  cloudfront_CachingDisabled = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"
  # https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/using-managed-origin-request-policies.html
  cloudfront_AllViewerExceptHostHeader = "b689b0a8-53d0-40ab-baf2-68738e2966ac"
  cloudfront_AIProxyOrigin             = "AIProxyOrigin"
  cloudfront_ApiEcsOrigin              = "ApiEcsOrigin"
  cloudfront_CloudflareProxy           = "CloudflareProxy"
  cloudfront_GatewayOrigin             = "GatewayOrigin"
  cloudfront_APIGatewayOrigin          = "APIGatewayOrigin"
  cloudfront_ProxyOrigin               = var.use_global_ai_proxy ? local.cloudfront_CloudflareProxy : local.cloudfront_AIProxyOrigin

  cloudfront_api_origin_id = var.enable_ecs_api ? local.cloudfront_ApiEcsOrigin : local.cloudfront_APIGatewayOrigin

  # /v1/proxy origin priority: hosted global → private gateway VPC origin →
  # ECS API ALB (when enable_ecs_api) → AI Proxy Lambda / Cloudflare.
  cloudfront_proxy_origin_id = (
    var.use_global_ai_gateway_origin ? local.cloudfront_GatewayOrigin : (
      local.enable_private_gateway_cloudfront_origin ? local.cloudfront_PrivateGatewayOrigin : (
        var.enable_ecs_api ? local.cloudfront_ApiEcsOrigin : local.cloudfront_ProxyOrigin
      )
    )
  )

  cloudfront_function_origin_id = var.enable_ecs_api ? local.cloudfront_ApiEcsOrigin : local.cloudfront_ProxyOrigin

  # When CloudFront reaches the ECS ALB over HTTP, the ALB sets X-Forwarded-Proto=http even
  # though the viewer connected to CloudFront over HTTPS. Add CloudFront-Forwarded-Proto so
  # the API can recover the viewer protocol. Do not use this policy for HTTPS origins because
  # forwarding the viewer Host header can make CloudFront validate the ALB certificate against
  # the viewer hostname; the ALB already sets X-Forwarded-Proto=https in that case.
  cloudfront_use_ecs_forwarded_proto_policy = var.enable_ecs_api && !var.api_ecs_alb_https_enabled
  cloudfront_ecs_origin_request_policy_id = (
    local.cloudfront_use_ecs_forwarded_proto_policy
    ? aws_cloudfront_origin_request_policy.all_viewer_with_forwarded_proto[0].id
    : local.cloudfront_AllViewerExceptHostHeader
  )
  cloudfront_origin_request_policy_for_origin = {
    (local.cloudfront_ApiEcsOrigin)          = local.cloudfront_ecs_origin_request_policy_id
    (local.cloudfront_APIGatewayOrigin)      = local.cloudfront_AllViewerExceptHostHeader
    (local.cloudfront_AIProxyOrigin)         = local.cloudfront_AllViewerExceptHostHeader
    (local.cloudfront_CloudflareProxy)       = local.cloudfront_AllViewerExceptHostHeader
    (local.cloudfront_GatewayOrigin)         = local.cloudfront_AllViewerExceptHostHeader
    (local.cloudfront_PrivateGatewayOrigin)  = local.cloudfront_AllViewerExceptHostHeader
  }
}

# Forwards all viewer headers/cookies/query strings plus CloudFront-Forwarded-Proto. This is
# safe only for the HTTP ECS origin; HTTPS origins must not forward the viewer Host header.
resource "aws_cloudfront_origin_request_policy" "all_viewer_with_forwarded_proto" {
  count = local.cloudfront_use_ecs_forwarded_proto_policy ? 1 : 0

  name    = "${var.deployment_name}-all-viewer-with-forwarded-proto"
  comment = "All viewer headers plus CloudFront-Forwarded-Proto (for HTTP ECS ALB origin)"

  cookies_config {
    cookie_behavior = "all"
  }

  headers_config {
    header_behavior = "allViewerAndWhitelistCloudFront"
    headers {
      items = ["CloudFront-Forwarded-Proto"]
    }
  }

  query_strings_config {
    query_string_behavior = "all"
  }
}

resource "aws_cloudfront_vpc_origin" "api_ecs" {
  vpc_origin_endpoint_config {
    name                   = "${var.deployment_name}-api-ecs"
    arn                    = var.api_ecs_alb_arn
    http_port              = 80
    https_port             = 443
    origin_protocol_policy = var.api_ecs_alb_https_enabled ? "https-only" : "http-only"

    origin_ssl_protocols {
      items    = ["TLSv1.2"]
      quantity = 1
    }
  }

  timeouts {
    create = "30m"
    update = "30m"
  }

  tags = local.common_tags
}

resource "aws_cloudfront_distribution" "dataplane" {
  comment      = "Braintrust Dataplane - ${var.deployment_name}"
  enabled      = true
  http_version = "http2and3"
  web_acl_id   = var.waf_acl_id
  price_class  = var.cloudfront_price_class
  aliases      = var.custom_domain != null ? [var.custom_domain] : null

  origin {
    origin_id   = local.cloudfront_APIGatewayOrigin
    origin_path = "/api"
    domain_name = "${aws_api_gateway_rest_api.api.id}.execute-api.${data.aws_region.current.region}.amazonaws.com"

    custom_origin_config {
      origin_protocol_policy   = "https-only"
      origin_read_timeout      = var.cloudfront_origin_read_timeout
      origin_keepalive_timeout = 60
      https_port               = 443
      http_port                = 80
      origin_ssl_protocols     = ["TLSv1.2"]
    }

    # This is required so that the MCP server can redirect to the correct domain
    dynamic "custom_header" {
      for_each = var.custom_domain != null ? [1] : []
      content {
        name  = "X-CloudFront-Domain"
        value = var.custom_domain
      }
    }
  }

  origin {
    domain_name = trimsuffix(trimprefix(var.ai_proxy_function_url, "https://"), "/")
    origin_id   = local.cloudfront_AIProxyOrigin

    custom_origin_config {
      origin_protocol_policy   = "https-only"
      origin_read_timeout      = var.cloudfront_origin_read_timeout
      origin_keepalive_timeout = 60
      https_port               = 443
      http_port                = 80
      origin_ssl_protocols     = ["TLSv1.2"]
    }
  }

  origin {
    domain_name = "braintrustproxy.com"
    origin_id   = local.cloudfront_CloudflareProxy

    custom_origin_config {
      origin_protocol_policy   = "https-only"
      origin_read_timeout      = var.cloudfront_origin_read_timeout
      origin_keepalive_timeout = 60
      https_port               = 443
      http_port                = 80
      origin_ssl_protocols     = ["TLSv1.2"]
    }
  }

  origin {
    domain_name = trimsuffix(replace(var.global_ai_gateway_origin_domain, "/^https?:\\/\\//", ""), "/")
    origin_id   = local.cloudfront_GatewayOrigin

    custom_origin_config {
      origin_protocol_policy   = "https-only"
      origin_read_timeout      = var.cloudfront_origin_read_timeout
      origin_keepalive_timeout = 60
      https_port               = 443
      http_port                = 80
      origin_ssl_protocols     = ["TLSv1.2"]
    }
  }

  origin {
    origin_id   = local.cloudfront_ApiEcsOrigin
    domain_name = var.api_ecs_alb_domain

    vpc_origin_config {
      vpc_origin_id            = aws_cloudfront_vpc_origin.api_ecs.id
      origin_keepalive_timeout = 60
      origin_read_timeout      = var.cloudfront_origin_read_timeout
    }

    dynamic "custom_header" {
      for_each = var.custom_domain != null ? [1] : []
      content {
        name  = "X-CloudFront-Domain"
        value = var.custom_domain
      }
    }
  }

  dynamic "origin" {
    for_each = local.enable_private_gateway_cloudfront_origin ? [1] : []
    content {
      domain_name = var.gateway_alb_dns_name
      origin_id   = local.cloudfront_PrivateGatewayOrigin

      vpc_origin_config {
        vpc_origin_id            = aws_cloudfront_vpc_origin.gateway[0].id
        origin_read_timeout      = var.cloudfront_origin_read_timeout
        origin_keepalive_timeout = 60
      }
    }
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods         = ["GET", "HEAD", "OPTIONS"]
    target_origin_id       = local.cloudfront_api_origin_id
    viewer_protocol_policy = "redirect-to-https"

    cache_policy_id          = local.cloudfront_CachingDisabled
    origin_request_policy_id = local.cloudfront_origin_request_policy_for_origin[local.cloudfront_api_origin_id]
  }

  dynamic "ordered_cache_behavior" {
    for_each = toset(["/v1/proxy", "/v1/proxy/*"])
    content {
      path_pattern           = ordered_cache_behavior.value
      allowed_methods        = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
      cached_methods         = ["GET", "HEAD", "OPTIONS"]
      target_origin_id       = local.cloudfront_proxy_origin_id
      viewer_protocol_policy = "redirect-to-https"

      cache_policy_id          = local.cloudfront_CachingDisabled
      origin_request_policy_id = local.cloudfront_origin_request_policy_for_origin[local.cloudfront_proxy_origin_id]
    }
  }

  dynamic "ordered_cache_behavior" {
    for_each = toset([
      "/v1/eval", "/v1/eval/*",
      "/v1/function/*/?*",
      "/function/*"
    ])
    content {
      path_pattern           = ordered_cache_behavior.value
      allowed_methods        = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
      cached_methods         = ["GET", "HEAD", "OPTIONS"]
      target_origin_id       = local.cloudfront_function_origin_id
      viewer_protocol_policy = "redirect-to-https"

      cache_policy_id          = local.cloudfront_CachingDisabled
      origin_request_policy_id = local.cloudfront_origin_request_policy_for_origin[local.cloudfront_function_origin_id]
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = var.custom_certificate_arn != null ? false : true
    acm_certificate_arn            = var.custom_certificate_arn

    # These can only be set if cloudfront_default_certificate is false
    minimum_protocol_version = var.custom_certificate_arn != null ? "TLSv1.3_2025" : null
    ssl_support_method       = var.custom_certificate_arn != null ? "sni-only" : null
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  tags = local.common_tags
}
