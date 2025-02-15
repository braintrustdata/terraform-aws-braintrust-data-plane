resource "aws_secretsmanager_secret" "clickhouse_secret" {
  name       = "${var.deployment_name}-clickhouse-secret"
  kms_key_id = var.kms_key_arn
}

data "aws_secretsmanager_random_password" "clickhouse_secret" {
  exclude_characters  = "\"'@/\\"
  exclude_punctuation = true
  password_length     = 32
}

resource "aws_secretsmanager_secret_version" "clickhouse_secret" {
  secret_id     = aws_secretsmanager_secret.clickhouse_secret.id
  secret_string = data.aws_secretsmanager_random_password.clickhouse_secret.random_password

  lifecycle {
    ignore_changes = [secret_string]
  }
}
