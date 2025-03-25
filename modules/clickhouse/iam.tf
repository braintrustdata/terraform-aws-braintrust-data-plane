resource "aws_iam_instance_profile" "clickhouse" {
  name = "${var.deployment_name}-ClickhouseInstanceProfile"
  role = aws_iam_role.clickhouse.name

  tags = local.common_tags
}

resource "aws_iam_role" "clickhouse" {
  name = "${var.deployment_name}-ClickhouseRole"

  assume_role_policy = jsonencode({ # nosemgrep
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy" "clickhouse_secret_access" {
  name = "AccessSecret"
  role = aws_iam_role.clickhouse.id
  policy = jsonencode({ # nosemgrep
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "secretsmanager:GetSecretValue"
      Resource = aws_secretsmanager_secret.clickhouse_secret.arn
    }]
  })
}

resource "aws_iam_role_policy" "clickhouse_s3_access" {
  name = "AccessS3Bucket"
  role = aws_iam_role.clickhouse.id
  policy = jsonencode({ # nosemgrep
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "s3:*"
        Resource = [
          "arn:aws:s3:::${local.clickhouse_bucket_name}",
          "arn:aws:s3:::${local.clickhouse_bucket_name}/*"
        ]
      },
      {
        Effect = "Deny"
        Action = "s3:*"
        Resource = [
          "arn:aws:s3:::${local.clickhouse_bucket_name}",
          "arn:aws:s3:::${local.clickhouse_bucket_name}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}


