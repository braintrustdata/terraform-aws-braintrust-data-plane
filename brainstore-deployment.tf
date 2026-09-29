locals {
  lambda_version_tag = var.lambda_version_tag_override != null ? var.lambda_version_tag_override : jsondecode(file("${path.module}/modules/services/VERSIONS.json"))["lambda_version_tag"]
}

module "brainstore_deployment" {
  source = "./modules/brainstore-deployment"
  count  = !var.use_deployment_mode_external_eks ? 1 : 0

  deployment_name          = var.deployment_name
  lambda_version_tag       = local.lambda_version_tag
  fleets                   = module.brainstore[0].deployment_fleets
  permissions_boundary_arn = var.permissions_boundary_arn
  custom_tags              = local.all_custom_tags
}
