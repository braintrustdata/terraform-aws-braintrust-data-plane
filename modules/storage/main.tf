# Common tags
locals {
  default_origins = [
    "https://braintrust.dev",
    "https://*.braintrust.dev",
    "https://*.preview.braintrust.dev",
  ]

  code_bundle_allowed_origins = distinct(concat(
    local.default_origins,
    var.s3_additional_allowed_origins,
    var.s3_code_bundle_additional_allowed_origins,
  ))

  lambda_responses_allowed_origins = distinct(concat(
    local.default_origins,
    var.s3_additional_allowed_origins,
    var.s3_lambda_responses_additional_allowed_origins,
  ))

  common_tags = merge({
    BraintrustDeploymentName = var.deployment_name
  }, var.custom_tags)

  # Object presence is known at plan time even when .bucket is unknown until apply
  # (e.g. destination bucket created in the same configuration).
  s3_server_access_logging_enabled = var.s3_server_access_logging != null
  s3_server_access_logging_prefix = (
    var.s3_server_access_logging != null && var.s3_server_access_logging.prefix != null
    ? var.s3_server_access_logging.prefix
    : "${var.deployment_name}/"
  )

  s3_server_access_logging_buckets = {
    brainstore       = aws_s3_bucket.brainstore.id
    code-bundle      = aws_s3_bucket.code_bundle_bucket.id
    lambda-responses = aws_s3_bucket.lambda_responses_bucket.id
  }
}
