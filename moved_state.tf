# Handle state migration since the VPC module became conditional
# This ensures existing users don't destroy/create their VPC resources when upgrading
moved {
  from = module.main_vpc
  to   = module.main_vpc[0]
}

# Handle state migration for S3 resources moved to storage module
# Brainstore S3 bucket
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

# Services S3 buckets
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

# Handle state migration for CloudFront and API Gateway resources moved to ingress module
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

# Handle state migration for IAM resources moved from brainstore to services-common
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

# Handle state migration for security group moved from brainstore to services-common
moved {
  from = module.brainstore[0].aws_security_group.brainstore_instance
  to   = module.services_common.aws_security_group.brainstore_instance
}

moved {
  from = module.brainstore[0].aws_vpc_security_group_egress_rule.brainstore_instance_allow_egress_all
  to   = module.services_common.aws_vpc_security_group_egress_rule.brainstore_instance_allow_egress_all
}

# Handle state migration for APIHandler IAM resources moved from services to services-common
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

# Handle state migration for function tools secret moved from services to services-common
moved {
  from = module.services.aws_secretsmanager_secret.function_tools_secret
  to   = module.services_common.aws_secretsmanager_secret.function_tools_secret
}
moved {
  from = module.services.aws_secretsmanager_secret_version.function_tools_secret
  to   = module.services_common.aws_secretsmanager_secret_version.function_tools_secret
}

# The services module is now conditional. Note that some resources were moved out into the services-common module.
moved {
  from = module.services
  to   = module.services[0]
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
