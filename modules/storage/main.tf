# Common tags
locals {
  default_origins = [
    "https://braintrust.dev",
    "https://*.braintrust.dev",
    "https://*.preview.braintrust.dev"
  ]

  all_origins = concat(local.default_origins, var.s3_additional_allowed_origins)

  common_tags = merge({
    BraintrustDeploymentName = var.deployment_name
  }, var.custom_tags)
}
