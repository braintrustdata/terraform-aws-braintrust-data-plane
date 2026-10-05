# This destination is customer bootstrap-owned; the data plane never creates it.
data "aws_partition" "diagnostics" {}
data "aws_caller_identity" "diagnostics" {}
locals {
  diagnostics_transcript_log_group_arn = var.diagnostics_transcript_log_group_name == null ? null : "arn:${data.aws_partition.diagnostics.partition}:logs:${data.aws_region.current.region}:${data.aws_caller_identity.diagnostics.account_id}:log-group:${var.diagnostics_transcript_log_group_name}:*"
}

resource "aws_iam_role_policy" "diagnostics_transcripts" {
  count = var.diagnostics_transcript_log_group_name != null && var.enable_execute_command ? 1 : 0
  name  = "DiagnosticsTranscriptDelivery"
  role  = aws_iam_role.task.id
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
resource "aws_iam_role_policy" "diagnostics_execute_command" {
  count = var.diagnostics_transcript_log_group_name != null && var.enable_execute_command ? 1 : 0
  name  = "DiagnosticsExecuteCommand"
  role  = aws_iam_role.task.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["ssmmessages:CreateControlChannel", "ssmmessages:CreateDataChannel", "ssmmessages:OpenControlChannel", "ssmmessages:OpenDataChannel"]
      Resource = "*"
    }]
  })
}
