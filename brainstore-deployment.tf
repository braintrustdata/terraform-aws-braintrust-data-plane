locals {
  lambda_version_tag = var.lambda_version_tag_override != null ? var.lambda_version_tag_override : jsondecode(file("${path.module}/modules/services/VERSIONS.json"))["lambda_version_tag"]
  api_version_tag    = var.braintrust_api_version_override != null ? var.braintrust_api_version_override : jsondecode(file("${path.module}/modules/api-ecs/VERSIONS.json"))["api"]

  brainstore_deployment_version = local.enable_ecs_api ? local.api_version_tag : local.lambda_version_tag
}

module "brainstore_deployment" {
  source = "./modules/brainstore-deployment"
  count  = !var.use_deployment_mode_external_eks ? 1 : 0

  deployment_name          = var.deployment_name
  version_tag              = local.brainstore_deployment_version
  fleets                   = module.brainstore[0].deployment_fleets
  permissions_boundary_arn = var.permissions_boundary_arn
  custom_tags              = local.all_custom_tags
}
