# Origin request policy is always created so enable_ecs_api rollback does not
# delete it in the same apply that detaches it from the CloudFront distribution.
moved {
  from = aws_cloudfront_origin_request_policy.all_viewer_with_forwarded_proto[0]
  to   = aws_cloudfront_origin_request_policy.all_viewer_with_forwarded_proto
}

# Count indexes so an enable_ecs_api=false upgrade moves API Gateway to [0]
# in place. Terraform moves surviving [0] resources back to the uncounted
# address on a module downgrade. Resources deleted by an enable_ecs_api=true
# apply are created again if the flag is set back to false or the module is
# downgraded after that apply.

moved {
  from = aws_api_gateway_rest_api.api
  to   = aws_api_gateway_rest_api.api[0]
}

moved {
  from = aws_api_gateway_deployment.api
  to   = aws_api_gateway_deployment.api[0]
}

moved {
  from = aws_api_gateway_stage.api
  to   = aws_api_gateway_stage.api[0]
}

moved {
  from = aws_api_gateway_method_settings.all
  to   = aws_api_gateway_method_settings.all[0]
}

moved {
  from = aws_lambda_permission.api_gateway
  to   = aws_lambda_permission.api_gateway[0]
}
