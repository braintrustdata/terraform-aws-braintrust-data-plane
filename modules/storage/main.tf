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

  # Brainstore bucket identity. In module-owned mode it comes from the managed
  # bucket; in external mode it is derived from the caller-provided ARN
  # (S3 ARNs have the form arn:aws:s3:::<bucket-name>).
  brainstore_bucket_arn = (
    var.create_brainstore_s3_bucket
    ? aws_s3_bucket.brainstore[0].arn
    : var.existing_brainstore_s3_bucket_arn
  )
  brainstore_bucket_id = (
    var.create_brainstore_s3_bucket
    ? aws_s3_bucket.brainstore[0].id
    : split(":::", var.existing_brainstore_s3_bucket_arn)[1]
  )

  # Object presence is known at plan time even when .bucket is unknown until apply
  # (e.g. destination bucket created in the same configuration).
  s3_server_access_logging_enabled = var.s3_server_access_logging != null
  s3_server_access_logging_prefix = (
    var.s3_server_access_logging == null
    ? "${var.deployment_name}/"
    : (
      var.s3_server_access_logging.prefix != null
      ? var.s3_server_access_logging.prefix
      : "${var.deployment_name}/"
    )
  )

  # Server access logging only applies to buckets this module owns. A
  # caller-provided Brainstore bucket is configured by its owner, not here.
  s3_server_access_logging_buckets = merge(
    var.create_brainstore_s3_bucket ? { brainstore = aws_s3_bucket.brainstore[0].id } : {},
    {
      code-bundle      = aws_s3_bucket.code_bundle_bucket.id
      lambda-responses = aws_s3_bucket.lambda_responses_bucket.id
    }
  )
}
