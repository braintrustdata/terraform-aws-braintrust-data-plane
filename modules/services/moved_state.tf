# Count indexes so enable_ecs_api can destroy APIHandler and AIProxy without
# recreating them on Lambda-mode stacks. Forward apply moves state in place.
# A module downgrade after apply addresses the uncounted resources and recreates them.

moved {
  from = aws_lambda_function.ai_proxy
  to   = aws_lambda_function.ai_proxy[0]
}

moved {
  from = aws_lambda_function_url.ai_proxy
  to   = aws_lambda_function_url.ai_proxy[0]
}

moved {
  from = aws_lambda_alias.ai_proxy_live
  to   = aws_lambda_alias.ai_proxy_live[0]
}

moved {
  from = aws_lambda_permission.ai_proxy
  to   = aws_lambda_permission.ai_proxy[0]
}

moved {
  from = aws_lambda_permission.ai_proxy_invoke
  to   = aws_lambda_permission.ai_proxy_invoke[0]
}

moved {
  from = aws_ssm_parameter.ai_proxy_url
  to   = aws_ssm_parameter.ai_proxy_url[0]
}

moved {
  from = aws_lambda_function.api_handler
  to   = aws_lambda_function.api_handler[0]
}

moved {
  from = aws_lambda_alias.api_handler_live
  to   = aws_lambda_alias.api_handler_live[0]
}

moved {
  from = aws_iam_role.ai_proxy_invoke_role
  to   = aws_iam_role.ai_proxy_invoke_role[0]
}

moved {
  from = aws_iam_role_policy.ai_proxy_invoke_policy
  to   = aws_iam_role_policy.ai_proxy_invoke_policy[0]
}

moved {
  from = aws_iam_role_policies_exclusive.ai_proxy_invoke_role
  to   = aws_iam_role_policies_exclusive.ai_proxy_invoke_role[0]
}
