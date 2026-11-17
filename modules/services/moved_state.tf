# Count indexes so an enable_ecs_api=false upgrade moves APIHandler and AIProxy
# to [0] in place. Terraform moves surviving [0] resources back to the uncounted
# address on a module downgrade, so a Lambda-mode stack is not recreated.
# An enable_ecs_api=true apply deletes these resources. Setting the flag back
# to false, or downgrading after that apply, creates them again, including a
# new Function URL hostname.

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

# The AIProxy invoke role, policy and reconciler now live in modules/iam. These
# three blocks stay for v6 state, which has no count here. The count arrived in
# v7.0.0, so a v6 stack chains through them to the root moved_state.tf blocks
# that carry the resources on to modules/iam.
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
