# # This file allows for a rollback from v3.0.0 of the module to the latest v2.x.x. It will be removed in the v3.0.0 release.

# # The services module is now conditional. Note that some resources were split out into the services-common module.
# moved {
#   from = module.services[0]
#   to   = module.services
# }

# # Brainstore S3 bucket moved from storage -> brainstore
# moved {
#   from = module.storage.aws_s3_bucket.brainstore
#   to   = module.brainstore[0].aws_s3_bucket.brainstore
# }

# moved {
#   from = module.storage.aws_s3_bucket_server_side_encryption_configuration.brainstore
#   to   = module.brainstore[0].aws_s3_bucket_server_side_encryption_configuration.brainstore
# }

# moved {
#   from = module.storage.aws_s3_bucket_versioning.brainstore
#   to   = module.brainstore[0].aws_s3_bucket_versioning.brainstore
# }

# moved {
#   from = module.storage.aws_s3_bucket_lifecycle_configuration.brainstore
#   to   = module.brainstore[0].aws_s3_bucket_lifecycle_configuration.brainstore
# }

# moved {
#   from = module.storage.aws_s3_bucket_public_access_block.brainstore
#   to   = module.brainstore[0].aws_s3_bucket_public_access_block.brainstore
# }

# # Code Bundle/Lambda Responses S3 buckets moved from storage -> services
# moved {
#   from = module.storage.aws_s3_bucket.code_bundle_bucket
#   to   = module.services.aws_s3_bucket.code_bundle_bucket
# }

# moved {
#   from = module.storage.aws_s3_bucket_server_side_encryption_configuration.code_bundle_bucket
#   to   = module.services.aws_s3_bucket_server_side_encryption_configuration.code_bundle_bucket
# }

# moved {
#   from = module.storage.aws_s3_bucket_cors_configuration.code_bundle_bucket
#   to   = module.services.aws_s3_bucket_cors_configuration.code_bundle_bucket
# }

# moved {
#   from = module.storage.aws_s3_bucket_lifecycle_configuration.code_bundle_bucket
#   to   = module.services.aws_s3_bucket_lifecycle_configuration.code_bundle_bucket
# }

# moved {
#   from = module.storage.aws_s3_bucket_public_access_block.code_bundle_bucket
#   to   = module.services.aws_s3_bucket_public_access_block.code_bundle_bucket
# }

# moved {
#   from = module.storage.aws_s3_bucket.lambda_responses_bucket
#   to   = module.services.aws_s3_bucket.lambda_responses_bucket
# }

# moved {
#   from = module.storage.aws_s3_bucket_lifecycle_configuration.lambda_responses_bucket
#   to   = module.services.aws_s3_bucket_lifecycle_configuration.lambda_responses_bucket
# }

# moved {
#   from = module.storage.aws_s3_bucket_cors_configuration.lambda_responses_bucket
#   to   = module.services.aws_s3_bucket_cors_configuration.lambda_responses_bucket
# }

# moved {
#   from = module.storage.aws_s3_bucket_server_side_encryption_configuration.lambda_responses_bucket
#   to   = module.services.aws_s3_bucket_server_side_encryption_configuration.lambda_responses_bucket
# }

# moved {
#   from = module.storage.aws_s3_bucket_public_access_block.lambda_responses_bucket
#   to   = module.services.aws_s3_bucket_public_access_block.lambda_responses_bucket
# }

# # CloudFront and API Gateway resources moved from ingress -> services
# moved {
#   from = module.ingress[0].aws_cloudfront_distribution.dataplane
#   to   = module.services.aws_cloudfront_distribution.dataplane
# }

# moved {
#   from = module.ingress[0].aws_api_gateway_rest_api.api
#   to   = module.services.aws_api_gateway_rest_api.api
# }

# moved {
#   from = module.ingress[0].aws_api_gateway_deployment.api
#   to   = module.services.aws_api_gateway_deployment.api
# }

# moved {
#   from = module.ingress[0].aws_api_gateway_stage.api
#   to   = module.services.aws_api_gateway_stage.api
# }

# moved {
#   from = module.ingress[0].aws_api_gateway_method_settings.all
#   to   = module.services.aws_api_gateway_method_settings.all
# }

# moved {
#   from = module.ingress[0].aws_lambda_permission.api_gateway
#   to   = module.services.aws_lambda_permission.api_gateway
# }

# # Brainstore IAM resources moved from services-common -> brainstore
# moved {
#   from = module.services_common.aws_iam_role.brainstore_role
#   to   = module.brainstore[0].aws_iam_role.brainstore_ec2_role
# }

# moved {
#   from = module.services_common.aws_iam_role_policy.brainstore_s3_access
#   to   = module.brainstore[0].aws_iam_role_policy.brainstore_s3_access
# }

# moved {
#   from = module.services_common.aws_iam_role_policy.brainstore_secrets_access
#   to   = module.brainstore[0].aws_iam_role_policy.brainstore_secrets_access
# }

# moved {
#   from = module.services_common.aws_iam_role_policy.brainstore_cloudwatch_logs_access
#   to   = module.brainstore[0].aws_iam_role_policy.brainstore_cloudwatch_logs_access
# }

# moved {
#   from = module.services_common.aws_iam_role_policy.brainstore_kms_policy
#   to   = module.brainstore[0].aws_iam_role_policy.brainstore_kms_policy
# }

# # Brainstore security group moved from services-common -> brainstore
# moved {
#   from = module.services_common.aws_security_group.brainstore_instance
#   to   = module.brainstore[0].aws_security_group.brainstore_instance
# }

# moved {
#   from = module.services_common.aws_vpc_security_group_egress_rule.brainstore_instance_allow_egress_all
#   to   = module.brainstore[0].aws_vpc_security_group_egress_rule.brainstore_instance_allow_egress_all
# }

# # APIHandler IAM resources moved from services-common -> services
# moved {
#   from = module.services_common.aws_iam_role.api_handler_role
#   to   = module.services.aws_iam_role.api_handler_role
# }

# moved {
#   from = module.services_common.aws_iam_policy.api_handler_policy
#   to   = module.services.aws_iam_policy.api_handler_policy
# }

# moved {
#   from = module.services_common.aws_iam_role_policy_attachment.api_handler_policy
#   to   = module.services.aws_iam_role_policy_attachment.api_handler_policy
# }

# moved {
#   from = module.services_common.aws_iam_role_policy_attachment.api_handler_additional_policy
#   to   = module.services.aws_iam_role_policy_attachment.api_handler_additional_policy
# }

# # Secrets from services-common -> services
# moved {
#   from = module.services_common.aws_secretsmanager_secret.function_tools_secret
#   to   = module.services.aws_secretsmanager_secret.function_tools_secret
# }
# moved {
#   from = module.services_common.aws_secretsmanager_secret_version.function_tools_secret
#   to   = module.services.aws_secretsmanager_secret_version.function_tools_secret
# }

# # Database subnet group is now optional
# moved {
#   from = module.database.aws_db_subnet_group.main[0]
#   to   = module.database.aws_db_subnet_group.main
# }

# # Revert bucket versioning
# moved {
#   from = module.storage.aws_s3_bucket_versioning.lambda_responses_bucket
#   to   = module.services.aws_s3_bucket_versioning.lambda_responses_bucket
# }

# moved {
#   from = module.storage.aws_s3_bucket_versioning.code_bundle_bucket
#   to   = module.services.aws_s3_bucket_versioning.code_bundle_bucket
# }
