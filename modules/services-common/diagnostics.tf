# This destination is customer bootstrap-owned; the data plane never creates it.
data "aws_partition" "diagnostics" {}
locals {
  diagnostics_transcript_log_group_arn = var.diagnostics_transcript_log_group_name == null ? null : "arn:${data.aws_partition.diagnostics.partition}:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:${var.diagnostics_transcript_log_group_name}:*"
}

resource "aws_iam_role_policy" "brainstore_diagnostics_transcripts" {
  count = var.diagnostics_transcript_log_group_name != null && var.enable_brainstore_ec2_ssm ? 1 : 0
  name  = "DiagnosticsTranscriptDelivery"
  role  = aws_iam_role.brainstore_role.id
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

resource "aws_iam_role_policy" "api_diagnostics_transcripts" {
  count = var.diagnostics_transcript_log_group_name != null && var.enable_ecs ? 1 : 0
  name  = "DiagnosticsTranscriptDelivery"
  role  = aws_iam_role.api_handler_role.id
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
