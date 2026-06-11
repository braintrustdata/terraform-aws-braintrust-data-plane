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
}
