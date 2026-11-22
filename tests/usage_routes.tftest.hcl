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
  enable_ecs_api            = false
}

run "usage_and_preflight_reach_the_api_handler" {
  command = plan
  module { source = "./modules/ingress" }

  assert {
    condition = try(
      toset(keys(jsondecode(aws_api_gateway_rest_api.api[0].body).paths["/usage"])) == toset(["options", "post"])
      && alltrue([
        for method in ["options", "post"] :
        jsondecode(aws_api_gateway_rest_api.api[0].body).paths["/usage"][method]["x-amazon-apigateway-integration"].uri
        == "arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/${var.api_handler_function_arn}/invocations"
      ]),
      false,
    )
    error_message = "POST /usage and its OPTIONS preflight must use the API handler Lambda integration."
  }
}
