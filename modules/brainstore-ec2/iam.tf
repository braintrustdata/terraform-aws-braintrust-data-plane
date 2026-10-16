resource "aws_iam_instance_profile" "brainstore" {
  name = "${var.deployment_name}-brainstore-instance-profile"
  role = var.brainstore_iam_role_name

  tags = local.common_tags
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
