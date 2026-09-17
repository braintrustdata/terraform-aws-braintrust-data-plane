data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_secretsmanager_secret_version" "postgres_credentials" {
  secret_id = local.postgres_credentials_secret_arn
}

data "aws_caller_identity" "current" {}
