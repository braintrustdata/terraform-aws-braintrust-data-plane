module "brainstore_deployment" {
  source = "./modules/brainstore-deployment"
  count  = !var.use_deployment_mode_external_eks ? 1 : 0

  deployment_name          = var.deployment_name
  fleets                   = module.brainstore[0].deployment_fleets
  permissions_boundary_arn = var.permissions_boundary_arn
  custom_tags              = local.all_custom_tags
}
