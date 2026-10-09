# v6.8.1 created these resources with count in restricted egress mode.
moved {
  from = aws_security_group.restricted_egress[0]
  to   = aws_security_group.restricted_egress
}

moved {
  from = aws_iam_role.network_connector_operator[0]
  to   = aws_iam_role.network_connector_operator
}

moved {
  from = aws_iam_role_policy_attachment.network_connector_operator[0]
  to   = aws_iam_role_policy_attachment.network_connector_operator
}

moved {
  from = aws_cloudformation_stack.restricted_egress_connector[0]
  to   = aws_cloudformation_stack.restricted_egress_connector
}
