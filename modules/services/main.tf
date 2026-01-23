locals {
  # Lambdas can only be deployed from s3 buckets in the same region. These are
  # the regions where we currently host our lambda code.
  # Contact support if you need a new region to be supported.
  supported_regions = ["us-east-1", "us-east-2", "us-west-2", "eu-west-1", "ca-central-1", "ap-southeast-2"]
  lambda_s3_bucket  = "braintrust-assets-${data.aws_region.current.region}"
  lambda_names      = ["AIProxy", "APIHandler", "MigrateDatabaseFunction", "QuarantineWarmupFunction", "CatchupETL", "BillingCron", "AutomationCron"]

  duckdb_nodejs_arm64_layer_arn   = "arn:aws:lambda:${data.aws_region.current.region}:041475135427:layer:duckdb-nodejs-arm64:14"
  observability_enabled           = nonsensitive(var.internal_observability_api_key != null && var.internal_observability_api_key != "")
  datadog_node_layer_arn          = "arn:aws:lambda:${data.aws_region.current.region}:464622532012:layer:Datadog-Node22-x:131"
  datadog_extension_arm_layer_arn = "arn:aws:lambda:${data.aws_region.current.region}:464622532012:layer:Datadog-Extension-ARM:90"
  datadog_python_layer_arn        = "arn:aws:lambda:${data.aws_region.current.region}:464622532012:layer:Datadog-Python313:118"
  datadog_extension_layer_arn     = "arn:aws:lambda:${data.aws_region.current.region}:464622532012:layer:Datadog-Extension:70"
  nodejs_datadog_handler          = "/opt/nodejs/node_modules/datadog-lambda-js/handler.handler"
  python_datadog_handler          = "datadog_lambda.handler.handler"
  datadog_env_vars = {
    DD_SITE            = "${var.internal_observability_region}.datadoghq.com"
    DD_API_KEY         = var.internal_observability_api_key != null ? var.internal_observability_api_key : ""
    DD_ENV             = var.internal_observability_env_name
    DD_VERSION         = local.lambda_version_tag
    DD_TAGS            = "braintrustdeploymentname:${var.deployment_name}"
    OTLP_HTTP_ENDPOINT = "http://localhost:4318"
  }

  # Extract bucket IDs from ARNs (format: arn:aws:s3:::bucket-name)
  code_bundle_bucket_id      = split(":::", var.code_bundle_bucket_arn)[1]
  lambda_responses_bucket_id = split(":::", var.lambda_responses_bucket_arn)[1]

  # Lambda versions can be specified statically through VERSIONS.json or dynamically via lambda_version_tag_override
  # If lambda_version_tag_override is provided, use it. Otherwise, use the lambda_version_tag from VERSIONS.json
  lambda_version_tag = var.lambda_version_tag_override != null ? var.lambda_version_tag_override : jsondecode(file("${path.module}/VERSIONS.json"))["lambda_version_tag"]

  lambda_versions = {
    for lambda in local.lambda_names :
    lambda => trimspace(data.http.lambda_versions[lambda].response_body)
  }

  postgres_url = "postgres://${var.postgres_username}:${var.postgres_password}@${var.postgres_host}:${var.postgres_port}/postgres"

  # Brainstore URLs - derived from internal brainstore module when enabled
  brainstore_dns_name        = var.brainstore_enabled ? module.brainstore[0].dns_name : null
  brainstore_writer_dns_name = var.brainstore_enabled && var.brainstore_writer_instance_count > 0 ? module.brainstore[0].writer_dns_name : null
  brainstore_port_internal   = var.brainstore_enabled ? module.brainstore[0].port : var.brainstore_port
  brainstore_url             = var.brainstore_enabled ? "http://${local.brainstore_dns_name}:${local.brainstore_port_internal}" : ""
  brainstore_writer_url      = var.brainstore_enabled && var.brainstore_writer_instance_count > 0 ? "http://${local.brainstore_writer_dns_name}:${local.brainstore_port_internal}" : ""

  # Extract bucket ID from ARN for brainstore
  brainstore_s3_bucket_id = var.brainstore_enabled && var.brainstore_s3_bucket_arn != null ? split(":::", var.brainstore_s3_bucket_arn)[1] : ""
  brainstore_s3_bucket    = local.brainstore_s3_bucket_id
  common_tags = merge({
    BraintrustDeploymentName = var.deployment_name
  }, var.custom_tags)
}

# Data source for dynamic lambda version lookups
data "http" "lambda_versions" {
  for_each = toset(local.lambda_names)

  url = "https://${local.lambda_s3_bucket}.s3.${data.aws_region.current.region}.amazonaws.com/lambda/${each.value}/version-${local.lambda_version_tag}"
}

data "aws_region" "current" {
  lifecycle {
    postcondition {
      condition     = contains(local.supported_regions, self.region)
      error_message = "Region must be one of: us-east-1, us-east-2, us-west-2, eu-west-1, ca-central-1, ap-southeast-2. Contact support if you need a new region to be supported."
    }
  }
}

data "aws_caller_identity" "current" {}
