locals {
  has_braintrust_support_access = var.enable_braintrust_support_logs_access || var.enable_braintrust_support_shell_access
}

# Role that can be assumed by Braintrust support team to optionally access Cloudwatch logs or optionally access the bastion host
resource "aws_iam_role" "braintrust_support" {
  count = local.has_braintrust_support_access ? 1 : 0

  name = "${var.deployment_name}-braintrust-support"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::872608195481:root" # Braintrust's AWS account
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    BraintrustDeploymentName = var.deployment_name
  }
}

resource "aws_iam_role_policy" "braintrust_support_logs" {
  count = var.enable_braintrust_support_logs_access ? 1 : 0

  name = "braintrust-support-logs-access"
  role = aws_iam_role.braintrust_support[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:DescribeLogStreams",
          "logs:GetLogEvents",
          "logs:FilterLogEvents",
          "logs:StartLiveTail",
          "logs:StopLiveTail"
        ]
        Resource = [
          "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/braintrust/${var.deployment_name}/*",
          "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/braintrust/${var.deployment_name}*:*",
          "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${var.deployment_name}*:*",
          "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${var.deployment_name}*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:DescribeLogGroups"
        ]
        # This is unavoidable. AWS does not allow restricting Describe calls.
        Resource = "*"
      }
    ]
  })
}

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

