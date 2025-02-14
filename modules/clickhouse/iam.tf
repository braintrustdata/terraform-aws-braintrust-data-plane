resource "aws_iam_instance_profile" "clickhouse" {
  name = "${var.deployment_name}-ClickhouseInstanceProfile"
  role = aws_iam_role.clickhouse.name
}

resource "aws_iam_role" "clickhouse" {
  name = "${var.deployment_name}-ClickhouseRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "clickhouse_secret_access" {
  name = "AccessSecret"
  role = aws_iam_role.clickhouse.id
  policy = jsonencode({
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
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = "s3:*"
      Resource = [
        "arn:aws:s3:::${aws_s3_bucket.clickhouse_s3_bucket.id}",
        "arn:aws:s3:::${aws_s3_bucket.clickhouse_s3_bucket.id}/*"
      ]
    }]
  })
}


