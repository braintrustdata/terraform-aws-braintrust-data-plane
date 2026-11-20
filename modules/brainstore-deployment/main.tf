data "aws_region" "current" {}

locals {
  function_name = "${var.deployment_name}-BrainstoreDeployment"
  asset_bucket  = "braintrust-assets-${data.aws_region.current.region}"
  common_tags   = merge(var.custom_tags, { BraintrustDeploymentName = var.deployment_name })
  deployment = {
    schema_version  = 1
    deployment_name = var.deployment_name
    fleets          = var.fleets
  }
}

data "http" "artifact" {
  url                = "https://${local.asset_bucket}.s3.${data.aws_region.current.region}.amazonaws.com/lambda/BrainstoreDeployment/version-${var.version_tag}"
  request_timeout_ms = 10000
  retry {
    attempts     = 5
    min_delay_ms = 500
    max_delay_ms = 5000
  }
  lifecycle {
    postcondition {
      condition     = self.status_code == 200 && can(regex("^lambda/BrainstoreDeployment/versions/[a-f0-9]+\\.zip$", trimspace(self.response_body)))
      error_message = "The BrainstoreDeployment artifact for API version ${var.version_tag} must be published in this region before using this module release."
    }
  }
}

resource "aws_cloudwatch_log_group" "waiter" {
  name              = "/braintrust/${var.deployment_name}/${local.function_name}"
  retention_in_days = 30
  tags              = local.common_tags
}

resource "aws_lambda_function" "waiter" {
  function_name = local.function_name
  role          = var.waiter_role_arn
  s3_bucket     = local.asset_bucket
  s3_key        = trimspace(data.http.artifact.response_body)
  runtime       = "nodejs22.x"
  architectures = ["arm64"]
  handler       = "index.handler"
  memory_size   = 256
  timeout       = 900
  logging_config {
    log_format = "JSON"
    log_group  = aws_cloudwatch_log_group.waiter.name
  }
  tags = local.common_tags
}
