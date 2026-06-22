resource "aws_cloudwatch_log_group" "braintrust_api" {
  name              = "/braintrust/${var.deployment_name}/braintrust-api"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = merge({
    Name = "${var.deployment_name}-braintrust-api-logs"
  }, local.common_tags)
}

resource "aws_cloudwatch_log_group" "braintrust_api_ingest" {
  name              = "/braintrust/${var.deployment_name}/braintrust-api-ingest"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = merge({
    Name = "${var.deployment_name}-braintrust-api-ingest-logs"
  }, local.common_tags)
}

resource "aws_cloudwatch_log_group" "braintrust_api_background" {
  name              = "/braintrust/${var.deployment_name}/braintrust-api-background"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = merge({
    Name = "${var.deployment_name}-braintrust-api-background-logs"
  }, local.common_tags)
}
