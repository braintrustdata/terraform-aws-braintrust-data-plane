locals {
  # CloudFront managed policy IDs (same values as in modules/ingress/cloudfront.tf).
  cloudfront_CachingDisabled           = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"
  cloudfront_AllViewerExceptHostHeader = "b689b0a8-53d0-40ab-baf2-68738e2966ac"
}

# CloudFront VPC Origin wrapping the internal NLB.
resource "aws_cloudfront_vpc_origin" "api" {
  vpc_origin_endpoint_config {
    name                   = "${var.deployment_name}-eks-api"
    arn                    = aws_lb.api.arn
    http_port              = 8000
    https_port             = 443
    origin_protocol_policy = "http-only"

    origin_ssl_protocols {
      items    = ["TLSv1.2"]
      quantity = 1
    }
  }

  tags = local.common_tags
}

# CloudFront distribution for the EKS-based dataplane.
resource "aws_cloudfront_distribution" "dataplane" {
  comment      = "Braintrust EKS Dataplane - ${var.deployment_name}"
  enabled      = true
  http_version = "http2and3"
  web_acl_id   = var.waf_acl_id
  price_class  = var.cloudfront_price_class
  aliases      = var.custom_domain != null ? [var.custom_domain] : null

  origin {
    origin_id   = "EKSAPIOrigin"
    domain_name = aws_lb.api.dns_name

    vpc_origin_config {
      vpc_origin_id            = aws_cloudfront_vpc_origin.api.id
      origin_read_timeout      = 60
      origin_keepalive_timeout = 60
    }

    dynamic "custom_header" {
      for_each = var.custom_domain != null ? [1] : []
      content {
        name  = "X-CloudFront-Domain"
        value = var.custom_domain
      }
    }
  }

  origin {
    domain_name = "braintrustproxy.com"
    origin_id   = "CloudflareProxy"

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
    target_origin_id       = "EKSAPIOrigin"
    viewer_protocol_policy = "redirect-to-https"

    cache_policy_id          = local.cloudfront_CachingDisabled
    origin_request_policy_id = local.cloudfront_AllViewerExceptHostHeader
  }

  # LLM-proxy / function-execution paths. Default target is the
  # in-cluster API pod (standalone-api handles these in Dataplane 2.0),
  # which is the correct behavior for a self-hosted deployment — keeps
  # request payloads inside the customer's AWS account instead of
  # round-tripping through Braintrust's hosted proxy.
  # `use_global_ai_proxy = true` flips the target to braintrustproxy.com;
  # matches the toggle semantics of the Lambda ingress module.
  dynamic "ordered_cache_behavior" {
    for_each = toset([
      "/v1/proxy", "/v1/proxy/*",
      "/v1/eval", "/v1/eval/*",
      "/v1/function/*/?*",
      "/function/*",
    ])
    content {
      path_pattern           = ordered_cache_behavior.value
      allowed_methods        = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
      cached_methods         = ["GET", "HEAD", "OPTIONS"]
      target_origin_id       = var.use_global_ai_proxy ? "CloudflareProxy" : "EKSAPIOrigin"
      viewer_protocol_policy = "redirect-to-https"

      cache_policy_id          = local.cloudfront_CachingDisabled
      origin_request_policy_id = local.cloudfront_AllViewerExceptHostHeader
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = var.custom_certificate_arn != null ? false : true
    acm_certificate_arn            = var.custom_certificate_arn
    minimum_protocol_version       = var.custom_certificate_arn != null ? "TLSv1.3_2025" : null
    ssl_support_method             = var.custom_certificate_arn != null ? "sni-only" : null
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  depends_on = [aws_cloudfront_vpc_origin.api]
  tags       = local.common_tags
}
