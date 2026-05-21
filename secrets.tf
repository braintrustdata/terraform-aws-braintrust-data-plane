resource "aws_secretsmanager_secret" "internal_observability_api_key" {
  count = local.enable_api_ecs && local.enable_internal_observability ? 1 : 0

  name                    = "${var.deployment_name}/internal-observability/api-key"
  recovery_window_in_days = 0
  kms_key_id              = local.kms_key_arn

  tags = merge({
    Name                     = "${var.deployment_name}-api-ecs-internal-observability-api-key"
    BraintrustDeploymentName = var.deployment_name
  }, var.custom_tags)
}

resource "aws_secretsmanager_secret_version" "internal_observability_api_key" {
  count = local.enable_api_ecs && local.enable_internal_observability ? 1 : 0

  secret_id     = aws_secretsmanager_secret.internal_observability_api_key[0].id
  secret_string = var.internal_observability_api_key
}

resource "aws_secretsmanager_secret" "api_ecs_native_inference_secret_key" {
  count = local.enable_api_ecs && nonsensitive(var.api_ecs_native_inference_secret_key) != "" ? 1 : 0

  name                    = "${var.deployment_name}/api-ecs/native-inference-secret-key"
  recovery_window_in_days = 0
  kms_key_id              = local.kms_key_arn

  tags = merge({
    Name                     = "${var.deployment_name}-api-ecs-native-inference-secret-key"
    BraintrustDeploymentName = var.deployment_name
  }, var.custom_tags)
}

resource "aws_secretsmanager_secret_version" "api_ecs_native_inference_secret_key" {
  count = local.enable_api_ecs && nonsensitive(var.api_ecs_native_inference_secret_key) != "" ? 1 : 0

  secret_id     = aws_secretsmanager_secret.api_ecs_native_inference_secret_key[0].id
  secret_string = var.api_ecs_native_inference_secret_key
}
