# Function tools secret for encryption
resource "aws_secretsmanager_secret" "function_tools_secret" {
  name_prefix = "${var.deployment_name}/FunctionToolsSecret-"
  description = "Function environment variables encryption key"
  kms_key_id  = var.kms_key_arn
  tags        = local.common_tags
}

data "aws_secretsmanager_random_password" "function_tools_secret" {
  exclude_characters  = "\"'@/\\"
  exclude_punctuation = true
  password_length     = 32
}

resource "aws_secretsmanager_secret_version" "function_tools_secret" {
  secret_id     = aws_secretsmanager_secret.function_tools_secret.id
  secret_string = data.aws_secretsmanager_random_password.function_tools_secret.random_password

  lifecycle {
    ignore_changes = [secret_string]
  }
}
