locals {
  # https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/using-managed-cache-policies.html#managed-cache-policy-caching-disabled
  cloudfront_CachingDisabled = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"
  # https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/using-managed-origin-request-policies.html
  cloudfront_AllViewerExceptHostHeader = "b689b0a8-53d0-40ab-baf2-68738e2966ac"
  cloudfront_AIProxyOrigin             = "AIProxyOrigin"
  cloudfront_CloudflareProxy           = "CloudflareProxy"
  cloudfront_APIGatewayOrigin          = "APIGatewayOrigin"
}

resource "aws_cloudfront_distribution" "dataplane" {
  comment      = "Braintrust Dataplane - ${var.deployment_name}"
  enabled      = true
  http_version = "http2and3"
  # Deploy only in North America and Europe. Reduces costs and deployment time.
  price_class = "PriceClass_100"
  aliases     = var.custom_domain != null ? [var.custom_domain] : null

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

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods         = ["GET", "HEAD", "OPTIONS"]
    target_origin_id       = local.cloudfront_APIGatewayOrigin
    viewer_protocol_policy = "redirect-to-https"

    cache_policy_id          = local.cloudfront_CachingDisabled
    origin_request_policy_id = local.cloudfront_AllViewerExceptHostHeader
  }

  dynamic "ordered_cache_behavior" {
    for_each = toset([
      "/v1/proxy", "/v1/proxy/*",
      "/v1/eval", "/v1/eval/*",
      "/v1/function/*/?*",
      "/function/*"
    ])
    content {
      path_pattern           = ordered_cache_behavior.value
      allowed_methods        = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
      cached_methods         = ["GET", "HEAD", "OPTIONS"]
      target_origin_id       = var.use_global_ai_proxy ? local.cloudfront_CloudflareProxy : local.cloudfront_AIProxyOrigin
      viewer_protocol_policy = "redirect-to-https"

      cache_policy_id          = local.cloudfront_CachingDisabled
      origin_request_policy_id = local.cloudfront_AllViewerExceptHostHeader
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = var.custom_certificate_arn != null ? false : true
    acm_certificate_arn            = var.custom_certificate_arn

    # These can only be set if cloudfront_default_certificate is false
    minimum_protocol_version = var.custom_certificate_arn != null ? "TLSv1.2_2021" : null
    ssl_support_method       = var.custom_certificate_arn != null ? "sni-only" : null
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  tags = local.common_tags
}
