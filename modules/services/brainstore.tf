# Brainstore EC2 module instantiation
# This module is nested under services to consolidate all compute services
module "brainstore" {
  source = "./brainstore-ec2"
  count  = var.brainstore_enabled ? 1 : 0

  deployment_name                       = var.deployment_name
  instance_count                        = var.brainstore_instance_count
  instance_type                         = var.brainstore_instance_type
  instance_key_pair_name                = var.brainstore_instance_key_pair_name
  port                                  = var.brainstore_port
  license_key                           = var.brainstore_license_key
  version_override                      = var.brainstore_version_override
  extra_env_vars                        = var.brainstore_extra_env_vars
  extra_env_vars_writer                 = var.brainstore_extra_env_vars_writer
  writer_instance_count                 = var.brainstore_writer_instance_count
  writer_instance_type                  = var.brainstore_writer_instance_type
  monitoring_telemetry                  = var.monitoring_telemetry
  database_host                         = var.database_host
  database_port                         = var.database_port
  database_secret_arn                   = var.database_secret_arn
  redis_host                            = var.redis_host
  redis_port                            = var.redis_port
  service_token_secret_key              = var.function_tools_secret_key
  brainstore_s3_bucket_arn              = var.brainstore_s3_bucket_arn
  internal_observability_api_key        = var.internal_observability_api_key
  internal_observability_env_name       = var.internal_observability_env_name
  internal_observability_region         = var.internal_observability_region
  brainstore_instance_security_group_id = var.brainstore_instance_security_group_id
  vpc_id                                = var.vpc_id
  # Merge external authorized security groups with internal lambda security group
  authorized_security_groups = merge(
    var.brainstore_authorized_security_groups,
    { "Lambda Services" = aws_security_group.lambda.id }
  )
  authorized_security_groups_ssh = var.brainstore_authorized_security_groups_ssh
  private_subnet_ids             = var.private_subnet_ids
  kms_key_arn                    = var.kms_key_arn
  brainstore_iam_role_name       = var.brainstore_iam_role_name
  custom_tags                    = var.custom_tags
  custom_post_install_script     = var.brainstore_custom_post_install_script
  cache_file_size_reader         = var.brainstore_cache_file_size_reader
  cache_file_size_writer         = var.brainstore_cache_file_size_writer
}
