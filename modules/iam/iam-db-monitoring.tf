resource "aws_iam_role" "db_monitoring" {
  count = var.create_iam ? 1 : 0

  name = local.role_names.db_monitoring

  assume_role_policy = jsonencode({ # nosemgrep
    Version = "2008-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      }
    ]
  })

  permissions_boundary = var.permissions_boundary_arn

  lifecycle {
    # Some live stacks have an older physical name. Wire consumers to this
    # resource's attributes, never to role_names, so they keep that name.
    ignore_changes = [name]
  }

  tags = local.iam_tags
}

resource "aws_iam_role_policy_attachment" "db_monitoring" {
  count = var.create_iam ? 1 : 0

  role       = aws_iam_role.db_monitoring[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}
