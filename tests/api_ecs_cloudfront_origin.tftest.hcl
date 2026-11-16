mock_provider "aws" {
  source = "./tests/mocks/aws"
}

variables {
  deployment_name    = "bt-test"
  enable_ecs_api     = true
  api_ecs_alb_arn    = "arn:aws:elasticloadbalancing:us-east-1:123456789012:loadbalancer/app/api/1111111111111111"
  api_ecs_alb_domain = "internal-api.us-east-1.elb.amazonaws.com"
}

run "public_http_origin_stays_attached_during_private_staging" {
  command = plan

  module {
    source = "./modules/ingress"
  }

  assert {
    condition = (
      length(aws_cloudfront_vpc_origin.api_ecs_http) == 0 &&
      aws_cloudfront_vpc_origin.api_ecs.vpc_origin_endpoint_config[0].origin_protocol_policy == "http-only" &&
      aws_cloudfront_vpc_origin.api_ecs.vpc_origin_endpoint_config[0].http_port == 80 &&
      aws_cloudfront_vpc_origin.api_ecs.vpc_origin_endpoint_config[0].arn == var.api_ecs_alb_arn &&
      local.cloudfront_use_ecs_forwarded_proto_policy
    )
    error_message = "CloudFront must use the ALB HTTP 80 path independently of customer HTTPS."
  }

  assert {
    condition     = length([for origin in aws_cloudfront_distribution.dataplane.origin : origin if origin.origin_id == "ApiEcsOrigin" && origin.domain_name == var.api_ecs_alb_domain]) == 1
    error_message = "The distribution must retain its API ALB origin on the AWS-assigned ALB hostname."
  }
}

run "legacy_https_origin_uses_new_http_origin" {
  command = plan

  module {
    source = "./modules/ingress"
  }

  variables {
    legacy_api_https_listener = true
  }

  assert {
    condition     = length(aws_cloudfront_vpc_origin.api_ecs_http) == 1 && aws_cloudfront_vpc_origin.api_ecs_http[0].vpc_origin_endpoint_config[0].origin_protocol_policy == "http-only"
    error_message = "Legacy HTTPS origins require a separate HTTP origin for the public distribution."
  }
}
