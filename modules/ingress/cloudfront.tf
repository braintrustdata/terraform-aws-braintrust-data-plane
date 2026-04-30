locals {
  # https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/using-managed-cache-policies.html#managed-cache-policy-caching-disabled
  cloudfront_CachingDisabled = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"
  # https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/using-managed-origin-request-policies.html
  cloudfront_AllViewerExceptHostHeader = "b689b0a8-53d0-40ab-baf2-68738e2966ac"
  cloudfront_APIGatewayOrigin          = "APIGatewayOrigin"
  cloudfront_AIProxyOrigin             = "AIProxyOrigin"
  cloudfront_CloudflareProxy           = "CloudflareProxy"
  cloudfront_APIECSOrigin              = "APIECSOrigin"
  cloudfront_proxy_origin              = var.use_global_ai_proxy ? local.cloudfront_CloudflareProxy : local.cloudfront_AIProxyOrigin

  default_ordered_cache_behaviors = [
    {
      path_pattern     = "/function/*"
      target_origin_id = local.cloudfront_proxy_origin
    },
    {
      path_pattern     = "/v1/eval"
      target_origin_id = local.cloudfront_proxy_origin
    },
    {
      path_pattern     = "/v1/eval/*"
      target_origin_id = local.cloudfront_proxy_origin
    },
    {
      path_pattern     = "/v1/function/*/?*"
      target_origin_id = local.cloudfront_proxy_origin
    },
    {
      path_pattern     = "/v1/proxy"
      target_origin_id = local.cloudfront_proxy_origin
    },
    {
      path_pattern     = "/v1/proxy/*"
      target_origin_id = local.cloudfront_proxy_origin
    },
  ]

  api_ecs_eval_ordered_cache_behaviors = [
    {
      path_pattern     = "/function/eval"
      target_origin_id = local.cloudfront_APIECSOrigin
    },
    {
      path_pattern     = "/function/sandbox"
      target_origin_id = local.cloudfront_APIECSOrigin
    },
    {
      path_pattern     = "/function/*"
      target_origin_id = local.cloudfront_AIProxyOrigin
    },
    {
      path_pattern     = "/v1/eval"
      target_origin_id = local.cloudfront_APIECSOrigin
    },
    {
      path_pattern     = "/v1/eval/*"
      target_origin_id = local.cloudfront_APIECSOrigin
    },
    {
      # Note that /v1/function and /v1/function/{id} still need to go to API Gateway.
      path_pattern     = "/v1/function/*/?*"
      target_origin_id = local.cloudfront_AIProxyOrigin
    },
    {
      path_pattern     = "/v1/proxy"
      target_origin_id = local.cloudfront_proxy_origin
    },
    {
      path_pattern     = "/v1/proxy/*"
      target_origin_id = local.cloudfront_proxy_origin
    },
  ]

  ordered_cache_behaviors = var.use_api_ecs_for_eval_routes ? local.api_ecs_eval_ordered_cache_behaviors : local.default_ordered_cache_behaviors
}

resource "aws_cloudfront_vpc_origin" "api_ecs" {
  count = var.use_api_ecs_for_eval_routes ? 1 : 0

  vpc_origin_endpoint_config {
    name                   = "${var.deployment_name}-api-ecs-origin"
    arn                    = var.api_ecs_origin_arn
    http_port              = 80
    https_port             = 443
    origin_protocol_policy = var.api_ecs_origin_protocol_policy

    origin_ssl_protocols {
      items    = ["TLSv1.2"]
      quantity = 1
    }
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
      origin_read_timeout      = 60
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
      origin_read_timeout      = 60
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
      origin_read_timeout      = 60
      origin_keepalive_timeout = 60
      https_port               = 443
      http_port                = 80
      origin_ssl_protocols     = ["TLSv1.2"]
    }
  }

  dynamic "origin" {
    for_each = var.use_api_ecs_for_eval_routes ? [1] : []
    content {
      domain_name = var.api_ecs_origin_domain_name
      origin_id   = local.cloudfront_APIECSOrigin

      vpc_origin_config {
        vpc_origin_id = aws_cloudfront_vpc_origin.api_ecs[0].id
      }
    }
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods         = ["GET", "HEAD", "OPTIONS"]
    target_origin_id       = local.cloudfront_APIGatewayOrigin
    viewer_protocol_policy = "redirect-to-https"

    cache_policy_id          = local.cloudfront_CachingDisabled
    origin_request_policy_id = local.cloudfront_AllViewerExceptHostHeader
  }

  dynamic "ordered_cache_behavior" {
    for_each = local.ordered_cache_behaviors

    content {
      path_pattern           = ordered_cache_behavior.value.path_pattern
      allowed_methods        = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
      cached_methods         = ["GET", "HEAD", "OPTIONS"]
      target_origin_id       = ordered_cache_behavior.value.target_origin_id
      viewer_protocol_policy = "redirect-to-https"

      cache_policy_id          = local.cloudfront_CachingDisabled
      origin_request_policy_id = local.cloudfront_AllViewerExceptHostHeader
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
