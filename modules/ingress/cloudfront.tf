locals {
  # https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/using-managed-cache-policies.html#managed-cache-policy-caching-disabled
  cloudfront_CachingDisabled = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"
  # https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/using-managed-origin-request-policies.html
  cloudfront_AllViewerExceptHostHeader = "b689b0a8-53d0-40ab-baf2-68738e2966ac"
  cloudfront_AIProxyOrigin             = "AIProxyOrigin"
  cloudfront_CloudflareProxy           = "CloudflareProxy"
  cloudfront_APIGatewayOrigin          = "APIGatewayOrigin"

  # CORS allowed origins: Braintrust control plane domains + any customer-provided origins.
  # Matches the pattern used in S3 bucket CORS (modules/storage/main.tf).
  cors_allowed_origins = concat(
    [
      "https://www.braintrust.dev",
      "https://braintrust.dev",
    ],
    var.cloudfront_additional_cors_origins
  )
}

# CORS response headers policy for the CloudFront distribution.
# Required for hybrid deployments where the browser at www.braintrust.dev
# makes cross-origin requests to the customer's data plane CloudFront.
resource "aws_cloudfront_response_headers_policy" "cors" {
  name = "${var.deployment_name}-cors-policy"

  cors_config {
    access_control_allow_credentials = true
    origin_override                  = true

    access_control_allow_headers {
      items = [
        "Authorization",
        "Content-Type",
        "X-Bt-Org-Name",
        "X-Bt-Project-Id",
        "X-Bt-Auth-Token",
        "X-Bt-Stream-Fmt",
      ]
    }

    access_control_allow_methods {
      items = ["GET", "HEAD", "OPTIONS", "POST", "PUT", "PATCH", "DELETE"]
    }

    access_control_allow_origins {
      items = local.cors_allowed_origins
    }

    access_control_max_age_sec = 3600
  }
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

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods         = ["GET", "HEAD", "OPTIONS"]
    target_origin_id       = local.cloudfront_APIGatewayOrigin
    viewer_protocol_policy = "redirect-to-https"

    cache_policy_id            = local.cloudfront_CachingDisabled
    origin_request_policy_id   = local.cloudfront_AllViewerExceptHostHeader
    response_headers_policy_id = aws_cloudfront_response_headers_policy.cors.id
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

      cache_policy_id            = local.cloudfront_CachingDisabled
      origin_request_policy_id   = local.cloudfront_AllViewerExceptHostHeader
      response_headers_policy_id = aws_cloudfront_response_headers_policy.cors.id
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
