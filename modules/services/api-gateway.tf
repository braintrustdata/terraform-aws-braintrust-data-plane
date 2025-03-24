resource "aws_api_gateway_rest_api" "api" {
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
  rest_api_id = aws_api_gateway_rest_api.api.id
  triggers = {
    redeployment = sha256(aws_api_gateway_rest_api.api.body)
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "api" {
  deployment_id = aws_api_gateway_deployment.api.id
  rest_api_id   = aws_api_gateway_rest_api.api.id
  stage_name    = "api"

  tags = merge({
    Name = "${var.deployment_name}-API-Stage"
  }, local.common_tags)
}

resource "aws_api_gateway_method_settings" "all" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  stage_name  = aws_api_gateway_stage.api.stage_name
  method_path = "*/*"
  settings {
    metrics_enabled = true
  }
}

resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api_handler.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/*/*"
}
