mock_provider "aws" {
  source = "./tests/mocks/aws"
}

variables {
  deployment_name                         = "bt-test"
  api_ecs_alb_arn                         = "arn:aws:elasticloadbalancing:us-east-1:123456789012:loadbalancer/app/api/1234567890abcdef"
  api_ecs_alb_domain                      = "api.example.internal"
  api_ecs_alb_https_enabled               = false
  api_handler_function_arn                = "arn:aws:lambda:us-east-1:123456789012:function:api-handler"
  ai_proxy_function_url                   = "https://proxy.example.lambda-url.us-east-1.on.aws/"
  use_private_ai_gateway_origin           = true
  gateway_alb_arn                         = "arn:aws:elasticloadbalancing:us-east-1:123456789012:loadbalancer/app/gateway/1234567890abcdef"
  gateway_alb_dns_name                    = "gateway.example.internal"
  gateway_cloudfront_ingress_rule_id      = "sgr-1234567890abcdef0"
  enable_loop_runtime                     = true
  loop_runtime_alb_arn                    = "arn:aws:elasticloadbalancing:us-east-1:123456789012:loadbalancer/app/loop/1234567890abcdef"
  loop_runtime_alb_dns_name               = "loop.example.internal"
  loop_runtime_cloudfront_ingress_rule_id = "sgr-abcdef01234567890"
}

run "defaults_preserve_existing_origin_settings" {
  command = apply

  module {
    source = "./modules/ingress"
  }

  assert {
    condition = length(aws_cloudfront_distribution.dataplane.origin) == 7 && alltrue([
      for origin in aws_cloudfront_distribution.dataplane.origin :
      origin.connection_attempts == 3 && try(origin.custom_origin_config[0].origin_read_timeout, origin.vpc_origin_config[0].origin_read_timeout) == 120
    ])
    error_message = "All CloudFront origins should retain 3 attempts and a 120-second read timeout by default."
  }
}

run "allows_higher_timeout_and_one_attempt" {
  command = apply

  module {
    source = "./modules/ingress"
  }

  variables {
    cloudfront_origin_read_timeout        = 600
    cloudfront_origin_connection_attempts = 1
  }

  assert {
    condition = length(aws_cloudfront_distribution.dataplane.origin) == 7 && alltrue([
      for origin in aws_cloudfront_distribution.dataplane.origin :
      origin.connection_attempts == 1 && try(origin.custom_origin_config[0].origin_read_timeout, origin.vpc_origin_config[0].origin_read_timeout) == 600
    ])
    error_message = "All CloudFront origins should use the configured timeout and connection attempts."
  }
}

run "rejects_zero_connection_attempts" {
  command = plan
  module {
    source = "./modules/ingress"
  }
  variables {
    cloudfront_origin_connection_attempts = 0
  }
  expect_failures = [var.cloudfront_origin_connection_attempts]
}

run "rejects_four_connection_attempts" {
  command = plan
  module {
    source = "./modules/ingress"
  }
  variables {
    cloudfront_origin_connection_attempts = 4
  }
  expect_failures = [var.cloudfront_origin_connection_attempts]
}

run "rejects_fractional_connection_attempts" {
  command = plan
  module {
    source = "./modules/ingress"
  }
  variables {
    cloudfront_origin_connection_attempts = 1.5
  }
  expect_failures = [var.cloudfront_origin_connection_attempts]
}

run "rejects_timeout_above_template_limit" {
  command = plan
  module {
    source = "./modules/ingress"
  }
  variables {
    cloudfront_origin_read_timeout = 601
  }
  expect_failures = [var.cloudfront_origin_read_timeout]
}
