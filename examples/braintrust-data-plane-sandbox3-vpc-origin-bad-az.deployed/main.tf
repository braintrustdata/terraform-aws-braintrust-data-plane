# tflint-ignore-file: terraform_module_pinned_source
#
# erikdw-sandbox3 — us-east-1 VPC origin bad-AZ upgrade test.
#
# Phase 1 (baseline on main): set module_source to main ref, use_private_ai_gateway_origin = false.
#   Gateway ALB spans all 3 subnets including use1-az3 (subnet 2).
# Phase 2 (upgrade): point module_source at branch with fixes, use_private_ai_gateway_origin = true.
#   Gateway ALB should shrink to 2 supported subnets; CloudFront /v1/proxy uses VPC origin.
#
# Apply: AWS_PROFILE=sandbox-usw2 terraform apply
# Requires: brainstore_license_key in terraform.tfvars or TF_VAR_brainstore_license_key

data "aws_availability_zone" "use1_az3" {
  zone_id = "use1-az3"
}

data "aws_availability_zones" "vpc_origin_supported" {
  state            = "available"
  exclude_zone_ids = ["use1-az3"]
}

locals {
  # Pin subnet 2 to use1-az3; subnets 1 and 3 to supported zones.
  private_subnet_1_az = data.aws_availability_zones.vpc_origin_supported.names[0]
  private_subnet_2_az = data.aws_availability_zone.use1_az3.name
  private_subnet_3_az = data.aws_availability_zones.vpc_origin_supported.names[1]

  # Phase 1: github.com/braintrustdata/terraform-aws-braintrust-data-plane?ref=main
  # Phase 2: ../../  (local branch with use_private_ai_gateway_origin fixes)
  module_source = "../../"
}

module "braintrust-data-plane" {
  source = local.module_source

  deployment_name     = "erikdw-sandbox3"
  braintrust_org_name = "erikdw-sandbox3"

  private_subnet_1_az = local.private_subnet_1_az
  private_subnet_2_az = local.private_subnet_2_az
  private_subnet_3_az = local.private_subnet_3_az

  create_ecs_api    = true
  enable_ecs_api    = true
  api_ecs_min_count = 1
  api_ecs_max_count = 3

  create_ai_gateway       = true
  enable_ai_gateway       = true
  ai_gateway_min_capacity = 1
  ai_gateway_max_capacity = 2
  ai_gateway_cpu          = 1024
  ai_gateway_memory       = 2048

  use_global_ai_gateway_origin  = false
  use_private_ai_gateway_origin = true

  brainstore_extra_env_vars = {
    BRAINSTORE_ASYNC_SCORING_USE_GATEWAY = "all"
  }

  postgres_instance_type              = "db.r8g.large"
  postgres_storage_size               = 100
  postgres_max_storage_size           = 500
  postgres_storage_type               = "gp3"
  postgres_storage_iops               = null
  postgres_storage_throughput         = null
  postgres_version                    = "15"
  postgres_auto_minor_version_upgrade = true

  DANGER_disable_database_deletion_protection = true

  brainstore_license_key = var.brainstore_license_key

  brainstore_instance_count             = 1
  brainstore_instance_type              = "c8gd.xlarge"
  brainstore_writer_instance_count      = 1
  brainstore_writer_instance_type       = "c8gd.xlarge"
  brainstore_fast_reader_instance_count = 0

  skip_pg_for_brainstore_objects = "all"
  enable_quarantine_vpc          = false

  redis_instance_type = "cache.t4g.small"
  redis_version       = "7.0"
}

output "private_subnet_azs" {
  description = "AZ placement chosen for this test (subnet 2 should map to use1-az3)."
  value = {
    subnet_1 = local.private_subnet_1_az
    subnet_2 = local.private_subnet_2_az
    subnet_3 = local.private_subnet_3_az
    use1_az3 = data.aws_availability_zone.use1_az3.name
  }
}

output "gateway_alb_subnet_ids" {
  description = "Subnets attached to the gateway ALB after apply (requires module with gateway_alb_subnet_ids output)."
  value       = try(module.braintrust-data-plane.gateway_alb_subnet_ids, null)
}

output "gateway_alb_dns_name" {
  value = module.braintrust-data-plane.gateway_alb_dns_name
}

output "api_url" {
  value = module.braintrust-data-plane.api_url
}
