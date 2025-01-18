module "main_vpc" {
  source = "./modules/vpc"

  deployment_name = var.deployment_name
  vpc_name        = "main"
  vpc_cidr        = var.vpc_cidr

  public_subnet_1_cidr  = cidrsubnet(var.vpc_cidr, 8, 0)
  public_subnet_1_az    = local.public_subnet_1_az
  private_subnet_1_cidr = cidrsubnet(var.vpc_cidr, 8, 1)
  private_subnet_1_az   = local.private_subnet_1_az
  private_subnet_2_cidr = cidrsubnet(var.vpc_cidr, 8, 2)
  private_subnet_2_az   = local.private_subnet_2_az
  private_subnet_3_cidr = cidrsubnet(var.vpc_cidr, 8, 3)
  private_subnet_3_az   = local.private_subnet_3_az
}

module "quarantine_vpc" {
  source = "./modules/vpc"
  count  = var.enable_quarantine ? 1 : 0

  deployment_name = var.deployment_name
  vpc_name        = "quarantine"
  vpc_cidr        = var.quarantine_vpc_cidr

  public_subnet_1_cidr  = cidrsubnet(var.quarantine_vpc_cidr, 8, 0)
  public_subnet_1_az    = local.quarantine_public_subnet_1_az
  private_subnet_1_cidr = cidrsubnet(var.quarantine_vpc_cidr, 8, 1)
  private_subnet_1_az   = local.quarantine_private_subnet_1_az
  private_subnet_2_cidr = cidrsubnet(var.quarantine_vpc_cidr, 8, 2)
  private_subnet_2_az   = local.quarantine_private_subnet_2_az
  private_subnet_3_cidr = cidrsubnet(var.quarantine_vpc_cidr, 8, 3)
  private_subnet_3_az   = local.quarantine_private_subnet_3_az
}

module "database" {
  source                 = "./modules/database"
  deployment_name        = var.deployment_name
  postgres_instance_type = var.postgres_instance_type
  postgres_storage_size  = var.postgres_storage_size
  postgres_storage_type  = var.postgres_storage_type
  postgres_version       = var.postgres_version
  database_subnet_ids = [
    module.main_vpc.private_subnet_1_id,
    module.main_vpc.private_subnet_2_id,
    module.main_vpc.private_subnet_3_id
  ]
  database_security_group_ids = [module.main_vpc.default_security_group_id]

  postgres_storage_iops       = var.postgres_storage_iops
  postgres_storage_throughput = var.postgres_storage_throughput
}

module "redis" {
  source = "./modules/elasticache"

  deployment_name = var.deployment_name
  subnet_ids = [
    module.main_vpc.private_subnet_1_id,
    module.main_vpc.private_subnet_2_id,
    module.main_vpc.private_subnet_3_id
  ]
  security_group_ids  = [module.main_vpc.default_security_group_id]
  redis_instance_type = var.redis_instance_type
  redis_version       = var.redis_version
}

module "services" {
  source = "./modules/services"

  deployment_name            = var.deployment_name
  braintrust_org_name        = var.braintrust_org_name
  postgres_username          = module.database.postgres_database_username
  postgres_password          = module.database.postgres_database_password
  postgres_host              = module.database.postgres_database_address
  redis_host                 = module.redis.redis_endpoint
  redis_port                 = module.redis.redis_port
  service_security_group_ids = [module.main_vpc.default_security_group_id]
  service_vpc_id             = module.main_vpc.vpc_id
  service_subnet_ids = [
    module.main_vpc.private_subnet_1_id,
    module.main_vpc.private_subnet_2_id,
    module.main_vpc.private_subnet_3_id
  ]
  use_quarantine_vpc                       = var.enable_quarantine
  quarantine_vpc_id                        = var.enable_quarantine ? module.quarantine_vpc[0].vpc_id : null
  quarantine_vpc_default_security_group_id = var.enable_quarantine ? module.quarantine_vpc[0].default_security_group_id : null
  quarantine_vpc_private_subnets = var.enable_quarantine ? [
    module.quarantine_vpc[0].private_subnet_1_id,
    module.quarantine_vpc[0].private_subnet_2_id,
    module.quarantine_vpc[0].private_subnet_3_id
  ] : []

}
