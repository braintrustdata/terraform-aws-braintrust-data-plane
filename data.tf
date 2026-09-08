data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_secretsmanager_secret_version" "postgres_credentials" {
  count     = var.postgres_credentials_secret_arn == null ? 0 : 1
  secret_id = var.postgres_credentials_secret_arn
}

data "aws_caller_identity" "current" {}
