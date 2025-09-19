locals {
  # Lambdas can only be deployed from s3 buckets in the same region. These are
  # the regions where we currently host our lambda code.
  # Contact support if you need a new region to be supported.
  supported_regions = ["us-east-1", "us-east-2", "us-west-2", "eu-west-1", "ca-central-1", "ap-southeast-2"]
  lambda_s3_bucket  = "braintrust-assets-${data.aws_region.current.name}"
  lambda_names      = ["AIProxy", "APIHandler", "MigrateDatabaseFunction", "QuarantineWarmupFunction", "CatchupETL", "BillingCron", "AutomationCron"]

  # Lambda versions can be specified statically through VERSIONS.json or dynamically via lambda_version_tag_override
  # If lambda_version_tag_override is provided, use it. Otherwise, use the lambda_version_tag from VERSIONS.json
  lambda_version_tag = var.lambda_version_tag_override != null ? var.lambda_version_tag_override : jsondecode(file("${path.module}/VERSIONS.json"))["lambda_version_tag"]

  lambda_versions = {
    for lambda in local.lambda_names :
    lambda => trimspace(data.http.lambda_versions[lambda].response_body)
  }

  postgres_url            = "postgres://${var.postgres_username}:${var.postgres_password}@${var.postgres_host}:${var.postgres_port}/postgres"
  using_brainstore_writer = var.brainstore_writer_hostname != null && var.brainstore_writer_hostname != ""
  brainstore_url          = var.brainstore_enabled ? "http://${var.brainstore_hostname}:${var.brainstore_port}" : ""
  brainstore_writer_url   = var.brainstore_enabled && local.using_brainstore_writer ? "http://${var.brainstore_writer_hostname}:${var.brainstore_port}" : ""
  brainstore_s3_bucket    = var.brainstore_enabled ? var.brainstore_s3_bucket_name : ""
  clickhouse_pg_url       = var.clickhouse_host != null ? "postgres://default:${var.clickhouse_secret}@${var.clickhouse_host}:9005/default" : ""
  clickhouse_connect_url  = var.clickhouse_host != null ? "http://default:${var.clickhouse_secret}@${var.clickhouse_host}:8123/default" : ""
  common_tags = {
    BraintrustDeploymentName = var.deployment_name
  }
}

# Data source for dynamic lambda version lookups
data "http" "lambda_versions" {
  for_each = toset(local.lambda_names)

  url = "https://${local.lambda_s3_bucket}.s3.${data.aws_region.current.name}.amazonaws.com/lambda/${each.value}/version-v${local.lambda_version_tag}"
}

data "aws_region" "current" {
  lifecycle {
    postcondition {
      condition     = contains(local.supported_regions, self.name)
      error_message = "Region must be one of: us-east-1, us-east-2, us-west-2, eu-west-1, ca-central-1, ap-southeast-2. Contact support if you need a new region to be supported."
    }
  }
}

data "aws_caller_identity" "current" {}
