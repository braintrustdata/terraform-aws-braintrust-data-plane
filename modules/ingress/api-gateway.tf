resource "aws_api_gateway_rest_api" "api" {
  count = var.enable_ecs_api ? 0 : 1

  name = "${var.deployment_name}-API"

  endpoint_configuration {
    types = ["EDGE"]
  }

  body = jsonencode(local.api_gateway_openapi_spec)

  tags = merge({
    Name = "${var.deployment_name}-API"
  }, local.common_tags)
}

resource "aws_api_gateway_deployment" "api" {
  count = var.enable_ecs_api ? 0 : 1

  rest_api_id = aws_api_gateway_rest_api.api[0].id
  triggers = {
    redeployment = sha256(aws_api_gateway_rest_api.api[0].body)
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "api" {
  count = var.enable_ecs_api ? 0 : 1

  deployment_id = aws_api_gateway_deployment.api[0].id
  rest_api_id   = aws_api_gateway_rest_api.api[0].id
  stage_name    = "api"

  tags = merge({
    Name = "${var.deployment_name}-API-Stage"
  }, local.common_tags)
}

resource "aws_api_gateway_method_settings" "all" {
  count = var.enable_ecs_api ? 0 : 1

  rest_api_id = aws_api_gateway_rest_api.api[0].id
  stage_name  = aws_api_gateway_stage.api[0].stage_name
  method_path = "*/*"
  settings {
    metrics_enabled = true
  }
}

resource "aws_lambda_permission" "api_gateway" {
  count = var.enable_ecs_api ? 0 : 1

  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = split(":", var.api_handler_function_arn)[6]
  principal     = "apigateway.amazonaws.com"
  source_arn    = "arn:aws:execute-api:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:${aws_api_gateway_rest_api.api[0].id}/*/*"
}
