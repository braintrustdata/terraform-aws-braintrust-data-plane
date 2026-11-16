resource "aws_iam_instance_profile" "brainstore" {
  name = "${var.deployment_name}-brainstore-instance-profile"
  role = var.brainstore_iam_role_name

  depends_on = [
    aws_iam_role_policy.brainstore_redis_secret_access,
    aws_iam_role_policy.brainstore_init,
  ]

  tags = local.common_tags
}

resource "aws_iam_role_policy" "brainstore_init" {
  name = "brainstore-init"
  role = var.brainstore_iam_role_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "cloudformation:DescribeStackResource"
      Resource = [for stack in aws_cloudformation_stack.brainstore_init : stack.id]
    }]
  })
}

# Create policy here to avoid dependency cycle with services-common
resource "aws_iam_role_policy" "brainstore_redis_secret_access" {
  name = "redis-secret-access"
  role = var.brainstore_iam_role_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "secretsmanager:GetSecretValue"
        Resource = var.redis_url_secret_arn
      }
    ]
  })
}
