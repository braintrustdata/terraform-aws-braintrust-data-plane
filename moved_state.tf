# Handle state migration since the VPC module became conditional
# This ensures existing users don't destroy/create their VPC resources when upgrading
moved {
  from = module.main_vpc
  to   = module.main_vpc[0]
}

# The services module is now conditional. Note that some resources were split out into the services-common module.
moved {
  from = module.services
  to   = module.services[0]
}

# Brainstore S3 bucket moved from brainstore -> storage
moved {
  from = module.brainstore[0].aws_s3_bucket.brainstore
  to   = module.storage.aws_s3_bucket.brainstore
}

moved {
  from = module.brainstore[0].aws_s3_bucket_server_side_encryption_configuration.brainstore
  to   = module.storage.aws_s3_bucket_server_side_encryption_configuration.brainstore
}

moved {
  from = module.brainstore[0].aws_s3_bucket_versioning.brainstore
  to   = module.storage.aws_s3_bucket_versioning.brainstore
}

moved {
  from = module.brainstore[0].aws_s3_bucket_lifecycle_configuration.brainstore
  to   = module.storage.aws_s3_bucket_lifecycle_configuration.brainstore
}

moved {
  from = module.brainstore[0].aws_s3_bucket_public_access_block.brainstore
  to   = module.storage.aws_s3_bucket_public_access_block.brainstore
}

# The module-owned Brainstore bucket resources became conditional
# (create_brainstore_s3_bucket) so the module can consume a caller-provided
# bucket instead. Each resource gains a count index; these moves keep existing
# module-owned buckets in place with no replacement. Chains with the
# brainstore -> storage moves above.
moved {
  from = module.storage.aws_s3_bucket.brainstore
  to   = module.storage.aws_s3_bucket.brainstore[0]
}

moved {
  from = module.storage.aws_s3_bucket_server_side_encryption_configuration.brainstore
  to   = module.storage.aws_s3_bucket_server_side_encryption_configuration.brainstore[0]
}

moved {
  from = module.storage.aws_s3_bucket_versioning.brainstore
  to   = module.storage.aws_s3_bucket_versioning.brainstore[0]
}

moved {
  from = module.storage.aws_s3_bucket_lifecycle_configuration.brainstore
  to   = module.storage.aws_s3_bucket_lifecycle_configuration.brainstore[0]
}

moved {
  from = module.storage.aws_s3_bucket_public_access_block.brainstore
  to   = module.storage.aws_s3_bucket_public_access_block.brainstore[0]
}

moved {
  from = module.storage.aws_s3_bucket_policy.brainstore
  to   = module.storage.aws_s3_bucket_policy.brainstore[0]
}

# Code Bundle/Lambda Responses S3 buckets moved from services -> storage
moved {
  from = module.services.aws_s3_bucket.code_bundle_bucket
  to   = module.storage.aws_s3_bucket.code_bundle_bucket
}

moved {
  from = module.services.aws_s3_bucket_server_side_encryption_configuration.code_bundle_bucket
  to   = module.storage.aws_s3_bucket_server_side_encryption_configuration.code_bundle_bucket
}

moved {
  from = module.services.aws_s3_bucket_cors_configuration.code_bundle_bucket
  to   = module.storage.aws_s3_bucket_cors_configuration.code_bundle_bucket
}

moved {
  from = module.services.aws_s3_bucket_lifecycle_configuration.code_bundle_bucket
  to   = module.storage.aws_s3_bucket_lifecycle_configuration.code_bundle_bucket
}

moved {
  from = module.services.aws_s3_bucket_public_access_block.code_bundle_bucket
  to   = module.storage.aws_s3_bucket_public_access_block.code_bundle_bucket
}

moved {
  from = module.services.aws_s3_bucket_versioning.code_bundle_bucket
  to   = module.storage.aws_s3_bucket_versioning.code_bundle_bucket
}

moved {
  from = module.services.aws_s3_bucket.lambda_responses_bucket
  to   = module.storage.aws_s3_bucket.lambda_responses_bucket
}

moved {
  from = module.services.aws_s3_bucket_lifecycle_configuration.lambda_responses_bucket
  to   = module.storage.aws_s3_bucket_lifecycle_configuration.lambda_responses_bucket
}

moved {
  from = module.services.aws_s3_bucket_cors_configuration.lambda_responses_bucket
  to   = module.storage.aws_s3_bucket_cors_configuration.lambda_responses_bucket
}

moved {
  from = module.services.aws_s3_bucket_server_side_encryption_configuration.lambda_responses_bucket
  to   = module.storage.aws_s3_bucket_server_side_encryption_configuration.lambda_responses_bucket
}

moved {
  from = module.services.aws_s3_bucket_public_access_block.lambda_responses_bucket
  to   = module.storage.aws_s3_bucket_public_access_block.lambda_responses_bucket
}

moved {
  from = module.services.aws_s3_bucket_versioning.lambda_responses_bucket
  to   = module.storage.aws_s3_bucket_versioning.lambda_responses_bucket
}

# The code bundle and Lambda response public access blocks became optional.
# Keep existing configurations in place when management remains enabled.
moved {
  from = module.storage.aws_s3_bucket_public_access_block.code_bundle_bucket
  to   = module.storage.aws_s3_bucket_public_access_block.code_bundle_bucket[0]
}

moved {
  from = module.storage.aws_s3_bucket_public_access_block.lambda_responses_bucket
  to   = module.storage.aws_s3_bucket_public_access_block.lambda_responses_bucket[0]
}

# CloudFront and API Gateway resources moved from services -> ingress
moved {
  from = module.services.aws_cloudfront_distribution.dataplane
  to   = module.ingress[0].aws_cloudfront_distribution.dataplane
}

moved {
  from = module.services.aws_api_gateway_rest_api.api
  to   = module.ingress[0].aws_api_gateway_rest_api.api
}

moved {
  from = module.services.aws_api_gateway_deployment.api
  to   = module.ingress[0].aws_api_gateway_deployment.api
}

moved {
  from = module.services.aws_api_gateway_stage.api
  to   = module.ingress[0].aws_api_gateway_stage.api
}

moved {
  from = module.services.aws_api_gateway_method_settings.all
  to   = module.ingress[0].aws_api_gateway_method_settings.all
}

moved {
  from = module.services.aws_lambda_permission.api_gateway
  to   = module.ingress[0].aws_lambda_permission.api_gateway
}

# Brainstore IAM resources moved from brainstore -> services-common
moved {
  from = module.brainstore[0].aws_iam_role.brainstore_ec2_role
  to   = module.services_common.aws_iam_role.brainstore_role
}

moved {
  from = module.brainstore[0].aws_iam_role_policy.brainstore_s3_access
  to   = module.services_common.aws_iam_role_policy.brainstore_s3_access
}

moved {
  from = module.brainstore[0].aws_iam_role_policy.brainstore_secrets_access
  to   = module.services_common.aws_iam_role_policy.brainstore_secrets_access
}

moved {
  from = module.brainstore[0].aws_iam_role_policy.brainstore_cloudwatch_logs_access
  to   = module.services_common.aws_iam_role_policy.brainstore_cloudwatch_logs_access
}

moved {
  from = module.brainstore[0].aws_iam_role_policy.brainstore_kms_policy
  to   = module.services_common.aws_iam_role_policy.brainstore_kms_policy
}

# Brainstore security group moved from brainstore -> services-common
moved {
  from = module.brainstore[0].aws_security_group.brainstore_instance
  to   = module.services_common.aws_security_group.brainstore_instance
}

moved {
  from = module.brainstore[0].aws_vpc_security_group_egress_rule.brainstore_instance_allow_egress_all
  to   = module.services_common.aws_vpc_security_group_egress_rule.brainstore_instance_allow_egress_all
}

# APIHandler IAM resources moved from services -> services-common
moved {
  from = module.services.aws_iam_role.api_handler_role
  to   = module.services_common.aws_iam_role.api_handler_role
}

moved {
  from = module.services.aws_iam_policy.api_handler_policy
  to   = module.services_common.aws_iam_policy.api_handler_policy
}

moved {
  from = module.services.aws_iam_role_policy_attachment.api_handler_policy
  to   = module.services_common.aws_iam_role_policy_attachment.api_handler_policy
}

moved {
  from = module.services.aws_iam_role_policy_attachment.api_handler_additional_policy
  to   = module.services_common.aws_iam_role_policy_attachment.api_handler_additional_policy
}

# Secrets from services -> services-common
moved {
  from = module.services.aws_secretsmanager_secret.function_tools_secret
  to   = module.services_common.aws_secretsmanager_secret.function_tools_secret
}
moved {
  from = module.services.aws_secretsmanager_secret_version.function_tools_secret
  to   = module.services_common.aws_secretsmanager_secret_version.function_tools_secret
}

# Database subnet group is now optional
moved {
  from = module.database.aws_db_subnet_group.main
  to   = module.database.aws_db_subnet_group.main[0]
}

# ElastiCache subnet group is now optional; preserve existing managed groups.
moved {
  from = module.redis.aws_elasticache_subnet_group.main
  to   = module.redis.aws_elasticache_subnet_group.main[0]
}

# Quarantine IAM resources moved from services -> services-common in an earlier
# release. They now live in modules/iam, and the blocks near the end of this
# file move them on from the services-common addresses below.
moved {
  from = module.services[0].aws_iam_role.quarantine_invoke_role
  to   = module.services_common.aws_iam_role.quarantine_invoke_role[0]
}

moved {
  from = module.services[0].aws_iam_role_policy.quarantine_invoke_policy
  to   = module.services_common.aws_iam_role_policy.quarantine_invoke_policy[0]
}

moved {
  from = module.services[0].aws_iam_role_policies_exclusive.quarantine_invoke_role
  to   = module.services_common.aws_iam_role_policies_exclusive.quarantine_invoke_role[0]
}

moved {
  from = module.services[0].aws_iam_role.quarantine_function_role
  to   = module.services_common.aws_iam_role.quarantine_function_role[0]
}

moved {
  from = module.services[0].aws_iam_role_policy_attachment.quarantine_function_role
  to   = module.services_common.aws_iam_role_policy_attachment.quarantine_function_role[0]
}

moved {
  from = module.services[0].aws_iam_policy.api_handler_quarantine[0]
  to   = module.services_common.aws_iam_policy.api_handler_quarantine[0]
}

moved {
  from = module.services[0].aws_iam_role_policy_attachment.api_handler_quarantine[0]
  to   = module.services_common.aws_iam_role_policy_attachment.api_handler_quarantine[0]
}

# Quarantine security group moved from services -> services-common
# This ensures the security group is available in both Lambda and EKS deployment modes
moved {
  from = module.services[0].aws_security_group.quarantine_lambda[0]
  to   = module.services_common.aws_security_group.quarantine_lambda[0]
}

moved {
  from = module.services[0].aws_security_group_rule.quarantine_lambda_allow_egress_all[0]
  to   = module.services_common.aws_security_group_rule.quarantine_lambda_allow_egress_all[0]
}

# Private gateway ALB moved from services-common -> gateway-alb.
# Keeps GATEWAY_URL creatable without depending on gateway-ecs (cycle break).
# Remove these after all stacks have applied once.
moved {
  from = module.services_common.aws_security_group.gateway_alb[0]
  to   = module.gateway_alb[0].aws_security_group.gateway_alb
}

moved {
  from = module.services_common.aws_security_group_rule.gateway_alb_ingress_from_authorized_security_groups["API"]
  to   = module.gateway_alb[0].aws_security_group_rule.gateway_alb_ingress_from_authorized_security_groups["API"]
}

moved {
  from = module.services_common.aws_security_group_rule.gateway_alb_ingress_from_authorized_security_groups["Brainstore"]
  to   = module.gateway_alb[0].aws_security_group_rule.gateway_alb_ingress_from_authorized_security_groups["Brainstore"]
}

moved {
  from = module.services_common.aws_security_group_rule.gateway_alb_egress_all[0]
  to   = module.gateway_alb[0].aws_security_group_rule.gateway_alb_egress_all
}

moved {
  from = module.services_common.aws_lb.gateway[0]
  to   = module.gateway_alb[0].aws_lb.gateway
}

moved {
  from = module.services_common.aws_lb_target_group.gateway[0]
  to   = module.gateway_alb[0].aws_lb_target_group.gateway
}

moved {
  from = module.services_common.aws_lb_listener.gateway_http[0]
  to   = module.gateway_alb[0].aws_lb_listener.gateway_http
}

# No-op if this ingress rule never existed under services-common.
moved {
  from = module.services_common.aws_vpc_security_group_ingress_rule.gateway_alb_from_cloudfront_vpc_origin[0]
  to   = module.gateway_alb[0].aws_vpc_security_group_ingress_rule.gateway_alb_from_cloudfront_vpc_origin[0]
}

# Loop data-store ingress rules moved to the modules that own the destination
# security groups. These moves preserve the existing AWS rules during upgrade.
moved {
  from = module.loop_runtime_ecs[0].aws_vpc_security_group_ingress_rule.postgres_from_task[0]
  to   = module.database.aws_vpc_security_group_ingress_rule.rds_allow_ingress_from_loop_runtime_security_groups["Loop Runtime"]
}

moved {
  from = module.loop_runtime_ecs[0].aws_vpc_security_group_ingress_rule.redis_from_task[0]
  to   = module.redis.aws_vpc_security_group_ingress_rule.elasticache_allow_ingress_from_loop_runtime_security_groups["Loop Runtime"]
}

moved {
  from = module.loop_runtime_ecs[0].aws_vpc_security_group_ingress_rule.brainstore_from_task[0]
  to   = module.brainstore[0].aws_vpc_security_group_ingress_rule.brainstore_elb_allow_ingress_from_loop_runtime_security_groups["Loop Runtime"]
}

moved {
  from = module.loop_runtime_ecs[0].aws_vpc_security_group_ingress_rule.gateway_from_task[0]
  to   = module.gateway_alb[0].aws_vpc_security_group_ingress_rule.gateway_alb_ingress_from_loop_runtime_security_groups["Loop Runtime"]
}

# Gateway task-exec secrets policy generalized beyond observability-only.
# No-op when observability was never enabled (resource absent from state).
moved {
  from = module.gateway_ecs[0].aws_iam_role_policy.task_execution_observability_secrets[0]
  to   = module.gateway_ecs[0].aws_iam_role_policy.task_execution_secrets
}

# IAM moved into modules/iam. Each move keeps the live role or policy, so an
# upgrade changes state only. The gateway custom CA and diagnostics policies
# already had a count, so their blocks name the whole resource on both sides and
# Terraform moves every instance.
#
# Rolling back to a module version without these blocks plans to destroy and
# recreate the roles, which changes their unique IDs. See MIGRATION_V8.md.
moved {
  from = module.database.aws_iam_role.db_monitoring
  to   = module.iam.aws_iam_role.db_monitoring[0]
}

moved {
  from = module.database.aws_iam_role_policy_attachment.db_monitoring
  to   = module.iam.aws_iam_role_policy_attachment.db_monitoring[0]
}

moved {
  from = module.brainstore_deployment[0].aws_iam_role.waiter
  to   = module.iam.aws_iam_role.brainstore_deployment_waiter[0]
}

moved {
  from = module.brainstore_deployment[0].aws_iam_role_policy.waiter
  to   = module.iam.aws_iam_role_policy.brainstore_deployment_waiter[0]
}

moved {
  from = module.api_ecs[0].aws_iam_role.task_execution
  to   = module.iam.aws_iam_role.api_ecs_task_execution[0]
}

moved {
  from = module.api_ecs[0].aws_iam_role_policy_attachment.task_execution_default
  to   = module.iam.aws_iam_role_policy_attachment.api_ecs_task_execution_default[0]
}

moved {
  from = module.api_ecs[0].aws_iam_role_policy.task_execution_secrets
  to   = module.iam.aws_iam_role_policy.api_ecs_task_execution_secrets[0]
}

moved {
  from = module.gateway_ecs[0].aws_iam_role.task_execution
  to   = module.iam.aws_iam_role.gateway_task_execution[0]
}

moved {
  from = module.gateway_ecs[0].aws_iam_role_policy_attachment.task_execution_default
  to   = module.iam.aws_iam_role_policy_attachment.gateway_task_execution_default[0]
}

moved {
  from = module.gateway_ecs[0].aws_iam_role_policy.task_execution_custom_ca_bundle_secret
  to   = module.iam.aws_iam_role_policy.gateway_task_execution_custom_ca_bundle_secret
}

moved {
  from = module.gateway_ecs[0].aws_iam_role_policy.task_execution_secrets
  to   = module.iam.aws_iam_role_policy.gateway_task_execution_secrets[0]
}

moved {
  from = module.gateway_ecs[0].aws_iam_role_policy.task_execution_redis_secret
  to   = module.iam.aws_iam_role_policy.gateway_task_execution_redis_secret[0]
}

moved {
  from = module.gateway_ecs[0].aws_iam_role.task
  to   = module.iam.aws_iam_role.gateway_task[0]
}

moved {
  from = module.gateway_ecs[0].aws_iam_role_policy.customer_assume_role
  to   = module.iam.aws_iam_role_policy.gateway_task_customer_assume_role[0]
}

moved {
  from = module.gateway_ecs[0].aws_iam_role_policy.diagnostics_transcripts
  to   = module.iam.aws_iam_role_policy.gateway_task_diagnostics_transcripts
}

moved {
  from = module.gateway_ecs[0].aws_iam_role_policy.diagnostics_execute_command
  to   = module.iam.aws_iam_role_policy.gateway_task_diagnostics_execute_command
}

# The blocks below start from the services-common, brainstore and services
# addresses that v3.0.0 and later releases use, which is where the older
# blocks above already move earlier state. Keep both sets: Terraform follows
# the chain, so dropping the older blocks stops pre-v3 state from reaching
# modules/iam.
#
# The shared API, quarantine and Brainstore roles and their policies moved from
# services-common into modules/iam. The additional policy attachments, the API
# CloudWatch, external attachment and diagnostics policies, and the Brainstore
# export, SSM and diagnostics resources already have a count in
# modules/services-common, so their blocks name the whole resource on both sides
# and Terraform moves every instance.
moved {
  from = module.services_common.aws_iam_role.api_handler_role
  to   = module.iam.aws_iam_role.api_handler[0]
}

moved {
  from = module.services_common.aws_iam_policy.api_handler_policy
  to   = module.iam.aws_iam_policy.api_handler[0]
}

moved {
  from = module.services_common.aws_iam_role_policy_attachment.api_handler_policy
  to   = module.iam.aws_iam_role_policy_attachment.api_handler[0]
}

moved {
  from = module.services_common.aws_iam_role_policy_attachment.api_handler_additional_policy
  to   = module.iam.aws_iam_role_policy_attachment.api_handler_additional_policy
}

moved {
  from = module.services_common.aws_iam_role_policy.api_handler_cloudwatch_metrics
  to   = module.iam.aws_iam_role_policy.api_handler_cloudwatch_metrics
}

moved {
  from = module.services_common.aws_iam_role_policy.api_handler_external_attachment_read
  to   = module.iam.aws_iam_role_policy.api_handler_external_attachment_read
}

moved {
  from = module.services_common.aws_iam_role_policy.api_diagnostics_transcripts
  to   = module.iam.aws_iam_role_policy.api_handler_diagnostics_transcripts
}

moved {
  from = module.services_common.aws_iam_role.quarantine_invoke_role[0]
  to   = module.iam.aws_iam_role.quarantine_invoke[0]
}

moved {
  from = module.services_common.aws_iam_role_policy.quarantine_invoke_policy[0]
  to   = module.iam.aws_iam_role_policy.quarantine_invoke[0]
}

moved {
  from = module.services_common.aws_iam_role_policies_exclusive.quarantine_invoke_role[0]
  to   = module.iam.aws_iam_role_policies_exclusive.quarantine_invoke[0]
}

moved {
  from = module.services_common.aws_iam_role.quarantine_function_role[0]
  to   = module.iam.aws_iam_role.quarantine_function[0]
}

moved {
  from = module.services_common.aws_iam_role_policy_attachment.quarantine_function_role[0]
  to   = module.iam.aws_iam_role_policy_attachment.quarantine_function_vpc_access[0]
}

moved {
  from = module.services_common.aws_iam_role_policy.quarantine_function_deny_ec2[0]
  to   = module.iam.aws_iam_role_policy.quarantine_function_deny_ec2[0]
}

moved {
  from = module.services_common.aws_iam_policy.api_handler_quarantine[0]
  to   = module.iam.aws_iam_policy.api_handler_quarantine[0]
}

moved {
  from = module.services_common.aws_iam_role_policy_attachment.api_handler_quarantine[0]
  to   = module.iam.aws_iam_role_policy_attachment.api_handler_quarantine[0]
}

moved {
  from = module.services_common.aws_iam_role.brainstore_role
  to   = module.iam.aws_iam_role.brainstore[0]
}

moved {
  from = module.services_common.aws_iam_role_policy.brainstore_s3_access
  to   = module.iam.aws_iam_role_policy.brainstore_s3_access[0]
}

moved {
  from = module.services_common.aws_iam_role_policy.brainstore_secrets_access
  to   = module.iam.aws_iam_role_policy.brainstore_secrets_access[0]
}

moved {
  from = module.services_common.aws_iam_role_policy.brainstore_export_assume_role
  to   = module.iam.aws_iam_role_policy.brainstore_export_assume_role
}

moved {
  from = module.services_common.aws_iam_role_policy.brainstore_cloudwatch_metrics
  to   = module.iam.aws_iam_role_policy.brainstore_cloudwatch_metrics[0]
}

moved {
  from = module.services_common.aws_iam_role_policy.brainstore_cloudwatch_logs_access
  to   = module.iam.aws_iam_role_policy.brainstore_cloudwatch_logs_access[0]
}

moved {
  from = module.services_common.aws_iam_role_policy_attachment.brainstore_ssm
  to   = module.iam.aws_iam_role_policy_attachment.brainstore_ssm
}

moved {
  from = module.services_common.aws_iam_role_policy_attachment.brainstore_additional_policy
  to   = module.iam.aws_iam_role_policy_attachment.brainstore_additional_policy
}

moved {
  from = module.services_common.aws_iam_role_policy.brainstore_kms_policy
  to   = module.iam.aws_iam_role_policy.brainstore_kms_policy[0]
}

moved {
  from = module.services_common.aws_iam_role_policy.brainstore_ssm_parameter_access
  to   = module.iam.aws_iam_role_policy.brainstore_ssm_parameter_access[0]
}

moved {
  from = module.services_common.aws_iam_role_policy.brainstore_diagnostics_transcripts
  to   = module.iam.aws_iam_role_policy.brainstore_diagnostics_transcripts
}

# The Brainstore instance profile and its Redis secret policy moved out of the
# brainstore module.
moved {
  from = module.brainstore[0].aws_iam_instance_profile.brainstore
  to   = module.iam.aws_iam_instance_profile.brainstore[0]
}

moved {
  from = module.brainstore[0].aws_iam_role_policy.brainstore_redis_secret_access
  to   = module.iam.aws_iam_role_policy.brainstore_redis_secret_access[0]
}

# The Lambda function roles moved out of the services module, along with the
# Lambda-path IAM: the APIHandler-Lambdas policy, its two attachments and the
# AIProxy invoke role. The AIProxy and quarantine pruner resources already have
# a count in modules/services, so their blocks keep the index.
moved {
  from = module.services[0].aws_iam_role.automation_cron_role
  to   = module.iam.aws_iam_role.automation_cron[0]
}

moved {
  from = module.services[0].aws_iam_role_policy_attachment.automation_cron_vpc_access
  to   = module.iam.aws_iam_role_policy_attachment.automation_cron_vpc_access[0]
}

moved {
  from = module.services[0].aws_iam_role_policy.automation_cron_topic_map_report_read
  to   = module.iam.aws_iam_role_policy.automation_cron_topic_map_report_read[0]
}

moved {
  from = module.services[0].aws_iam_role.billing_cron
  to   = module.iam.aws_iam_role.billing_cron[0]
}

moved {
  from = module.services[0].aws_iam_role_policy_attachment.billing_cron_vpc_access
  to   = module.iam.aws_iam_role_policy_attachment.billing_cron_vpc_access[0]
}

moved {
  from = module.services[0].aws_iam_role.catchup_etl
  to   = module.iam.aws_iam_role.catchup_etl[0]
}

moved {
  from = module.services[0].aws_iam_role_policy_attachment.catchup_etl_vpc_access
  to   = module.iam.aws_iam_role_policy_attachment.catchup_etl_vpc_access[0]
}

moved {
  from = module.services[0].aws_iam_role.migrate_database
  to   = module.iam.aws_iam_role.migrate_database[0]
}

moved {
  from = module.services[0].aws_iam_role_policy_attachment.migrate_database_vpc_access
  to   = module.iam.aws_iam_role_policy_attachment.migrate_database_vpc_access[0]
}

moved {
  from = module.services[0].aws_iam_role.default_role
  to   = module.iam.aws_iam_role.default[0]
}

moved {
  from = module.services[0].aws_iam_role_policy_attachment.lambda_vpc_access
  to   = module.iam.aws_iam_role_policy_attachment.default_vpc_access[0]
}

moved {
  from = module.services[0].aws_iam_role_policy.default_role_policy
  to   = module.iam.aws_iam_role_policy.default[0]
}

moved {
  from = module.services[0].aws_iam_role.quarantine_pruner_role[0]
  to   = module.iam.aws_iam_role.quarantine_pruner[0]
}

moved {
  from = module.services[0].aws_iam_role_policy_attachment.quarantine_pruner_vpc_access[0]
  to   = module.iam.aws_iam_role_policy_attachment.quarantine_pruner_vpc_access[0]
}

moved {
  from = module.services[0].aws_iam_role_policy.quarantine_pruner_delete_versions[0]
  to   = module.iam.aws_iam_role_policy.quarantine_pruner_delete_versions[0]
}

moved {
  from = module.services[0].aws_iam_role.quarantine_warmup[0]
  to   = module.iam.aws_iam_role.quarantine_warmup[0]
}

moved {
  from = module.services[0].aws_iam_role_policy_attachment.quarantine_warmup_vpc_access[0]
  to   = module.iam.aws_iam_role_policy_attachment.quarantine_warmup_vpc_access[0]
}

moved {
  from = module.services[0].aws_iam_role_policy.quarantine_warmup[0]
  to   = module.iam.aws_iam_role_policy.quarantine_warmup[0]
}

moved {
  from = module.services[0].aws_iam_role_policy_attachment.vpc_access
  to   = module.iam.aws_iam_role_policy_attachment.api_handler_vpc_access[0]
}

moved {
  from = module.services[0].aws_iam_policy.api_handler_lambda_policies
  to   = module.iam.aws_iam_policy.api_handler_lambda_policies[0]
}

moved {
  from = module.services[0].aws_iam_role_policy_attachment.api_handler_lambda_policies
  to   = module.iam.aws_iam_role_policy_attachment.api_handler_lambda_policies[0]
}

moved {
  from = module.services[0].aws_iam_role.ai_proxy_invoke_role[0]
  to   = module.iam.aws_iam_role.ai_proxy_invoke[0]
}

moved {
  from = module.services[0].aws_iam_role_policy.ai_proxy_invoke_policy[0]
  to   = module.iam.aws_iam_role_policy.ai_proxy_invoke[0]
}

moved {
  from = module.services[0].aws_iam_role_policies_exclusive.ai_proxy_invoke_role[0]
  to   = module.iam.aws_iam_role_policies_exclusive.ai_proxy_invoke[0]
}
