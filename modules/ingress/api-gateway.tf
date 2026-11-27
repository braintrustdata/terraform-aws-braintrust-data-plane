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

  # The CloudFront distribution depends on this stage. create_before_destroy
  # makes that distribution update finish before this stage is destroyed when
  # enable_ecs_api removes API Gateway. The stage name is fixed, so routine
  # applies update it in place rather than replacing it.
  lifecycle {
    create_before_destroy = true
  }
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

  # Unique suffix, not a fixed statement id. create_before_destroy adds the
  # replacement grant before deleting the previous one. Lambda rejects a
  # second statement with the same id, which is what a REST API replacement
  # would do while APIHandler stays.
  statement_id_prefix = "AllowAPIGatewayInvoke"
  action              = "lambda:InvokeFunction"
  function_name       = split(":", var.api_handler_function_arn)[6]
  principal           = "apigateway.amazonaws.com"
  source_arn          = "arn:aws:execute-api:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:${aws_api_gateway_rest_api.api[0].id}/*/*"

  # API Gateway cannot invoke APIHandler without this permission. Same cutover
  # ordering as the stage.
  lifecycle {
    create_before_destroy = true
  }
}
