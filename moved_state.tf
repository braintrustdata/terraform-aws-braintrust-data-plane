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
