resource "aws_secretsmanager_secret" "database_url_override" {
  count = local.use_postgres_connection_override ? 1 : 0

  name_prefix = "${var.deployment_name}/DatabaseUrlOverride-${local.database_url_override_suffix}-"
  description = "PostgreSQL URL for the configured database connection"
  kms_key_id  = local.kms_key_arn

  lifecycle {
    create_before_destroy = true
  }

  tags = merge({
    BraintrustDeploymentName = var.deployment_name
  }, local.all_custom_tags)
}

resource "aws_secretsmanager_secret_version" "database_url_override" {
  count = length(aws_secretsmanager_secret.database_url_override)

  secret_id = aws_secretsmanager_secret.database_url_override[0].id
  # urlencode uses query-string encoding for spaces; PostgreSQL URIs require %20.
  secret_string = "postgres://${replace(urlencode(local.postgres_username), "+", "%20")}:${replace(urlencode(local.postgres_password), "+", "%20")}@${local.postgres_host}:${module.database.postgres_database_port}/postgres?sslmode=require"
}

resource "aws_secretsmanager_secret" "internal_observability_api_key" {
  count = local.create_internal_observability_secret ? 1 : 0

  name                    = "${var.deployment_name}/internal-observability/api-key"
  recovery_window_in_days = 0
  kms_key_id              = local.kms_key_arn

  tags = merge({
    Name                     = "${var.deployment_name}-internal-observability-api-key"
    BraintrustDeploymentName = var.deployment_name
  }, local.all_custom_tags)
}

resource "aws_secretsmanager_secret_version" "internal_observability_api_key" {
  count = local.create_internal_observability_secret ? 1 : 0

  secret_id     = aws_secretsmanager_secret.internal_observability_api_key[0].id
  secret_string = var.internal_observability_api_key
}
