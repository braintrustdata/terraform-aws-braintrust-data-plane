# This destination is customer bootstrap-owned; the data plane never creates it.
locals {
  diagnostics_transcript_log_group_arn = var.diagnostics_transcript_log_group_name == null ? null : "arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:${var.diagnostics_transcript_log_group_name}:*"
  gateway_diagnostics_enabled          = var.diagnostics_transcript_log_group_name != null && var.ai_gateway_enable_execute_command
}

resource "aws_iam_role_policy" "gateway_task_diagnostics_transcripts" {
  count = var.create_iam && local.create_ai_gateway && local.gateway_diagnostics_enabled ? 1 : 0
  name  = "DiagnosticsTranscriptDelivery"
  role  = aws_iam_role.gateway_task[0].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Effect = "Allow", Action = ["logs:DescribeLogGroups"], Resource = "*" },
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogStream", "logs:DescribeLogStreams", "logs:PutLogEvents"]
        Resource = local.diagnostics_transcript_log_group_arn
      }
    ]
  })
}

# Legacy gateway Exec behavior is unchanged when the transcript input is unset.
resource "aws_iam_role_policy" "gateway_task_diagnostics_execute_command" {
  count = var.create_iam && local.create_ai_gateway && local.gateway_diagnostics_enabled ? 1 : 0
  name  = "DiagnosticsExecuteCommand"
  role  = aws_iam_role.gateway_task[0].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["ssmmessages:CreateControlChannel", "ssmmessages:CreateDataChannel", "ssmmessages:OpenControlChannel", "ssmmessages:OpenDataChannel"]
      Resource = "*"
    }]
  })
}
