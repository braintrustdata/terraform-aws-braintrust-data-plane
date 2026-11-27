mock_provider "aws" {
  source = "./tests/mocks/aws"
}

variables {
  deployment_name           = "bt-test"
  api_ecs_alb_arn           = "arn:aws:elasticloadbalancing:us-east-1:123456789012:loadbalancer/app/api/1111111111111111"
  api_ecs_alb_domain        = "internal-api.us-east-1.elb.amazonaws.com"
  api_ecs_alb_https_enabled = false
  api_handler_function_arn  = "arn:aws:lambda:us-east-1:123456789012:function:api"
  ai_proxy_function_url     = "https://proxy.lambda-url.us-east-1.on.aws/"
}

run "voice_disabled_preserves_ingress" {
  command = plan
  module { source = "./modules/ingress" }
  assert {
    condition = !anytrue([
      for behavior in aws_cloudfront_distribution.dataplane.ordered_cache_behavior :
      contains(["/v1/project/*/simulated_user/*/session", "/v1/voice_session/*/connect"], behavior.path_pattern)
    ])
    error_message = "Voice-disabled deployments must not get voice-specific CloudFront behaviors."
  }
}

run "voice_bypasses_lambda_ingress" {
  command = plan
  module { source = "./modules/ingress" }
  variables {
    enable_ecs_api        = false
    enable_voice_sessions = true
  }
  assert {
    condition = (
      aws_cloudfront_distribution.dataplane.default_cache_behavior[0].target_origin_id == "APIGatewayOrigin"
      && length([
        for behavior in aws_cloudfront_distribution.dataplane.ordered_cache_behavior : behavior
        if contains(["/v1/project/*/simulated_user/*/session", "/v1/voice_session/*/connect"], behavior.path_pattern)
        && behavior.target_origin_id == "ApiEcsOrigin"
        && behavior.cache_policy_id == "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"
        && contains(behavior.allowed_methods, "POST") && contains(behavior.allowed_methods, "GET") && contains(behavior.allowed_methods, "OPTIONS")
      ]) == 2
      && local.cloudfront_use_ecs_forwarded_proto_policy
    )
    error_message = "Both uncached voice paths must reach ECS while normal API requests retain Lambda ingress and viewer protocol forwarding."
  }
  assert {
    condition     = aws_cloudfront_origin_request_policy.all_viewer_with_forwarded_proto.headers_config[0].header_behavior == "allViewerAndWhitelistCloudFront"
    error_message = "The HTTP voice origin must forward authorization and WebSocket upgrade headers."
  }

  assert {
    condition = (
      toset(keys(jsondecode(aws_api_gateway_rest_api.api[0].body).paths["/sysadmin/{op}"])) == toset(["options", "post"]) &&
      alltrue([
        for method in values(jsondecode(aws_api_gateway_rest_api.api[0].body).paths["/sysadmin/{op}"]) :
        method["x-amazon-apigateway-integration"].httpMethod == "POST" &&
        one(method.parameters).name == "op" && one(method.parameters).in == "path" &&
        one(method.parameters).required && one(method.parameters).type == "string"
      ])
    )
    error_message = "API Gateway must forward secret-rotation POST requests and OPTIONS preflights to the API Lambda."
  }
}

run "voice_with_ecs_https_origin" {
  command = plan
  module { source = "./modules/ingress" }
  variables {
    enable_ecs_api            = true
    enable_voice_sessions     = true
    api_ecs_alb_https_enabled = true
    api_ecs_alb_domain        = "origin.example.com"
  }
  assert {
    condition = alltrue([
      for behavior in aws_cloudfront_distribution.dataplane.ordered_cache_behavior : (
        behavior.target_origin_id == "ApiEcsOrigin"
        && behavior.origin_request_policy_id == "b689b0a8-53d0-40ab-baf2-68738e2966ac"
      ) if contains(["/v1/project/*/simulated_user/*/session", "/v1/voice_session/*/connect"], behavior.path_pattern)
    ])
    error_message = "HTTPS ALB voice routes must avoid forwarding the viewer Host header."
  }
}
