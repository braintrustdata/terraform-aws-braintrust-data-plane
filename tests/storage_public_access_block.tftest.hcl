# Plan-only tests: opting out skips configuration, not the buckets or their
# other controls. No AWS calls are made.
mock_provider "aws" {}

variables {
  deployment_name = "bt-test"
}

run "managed_by_default" {
  command = plan

  module {
    source = "./modules/storage"
  }

  assert {
    condition = (
      var.manage_s3_public_access_block &&
      length(aws_s3_bucket_public_access_block.brainstore) == 1 &&
      length(aws_s3_bucket_public_access_block.code_bundle_bucket) == 1 &&
      length(aws_s3_bucket_public_access_block.lambda_responses_bucket) == 1
    )
    error_message = "Manage public access blocks on all three storage buckets by default."
  }

  assert {
    condition = alltrue(flatten([
      for block in concat(
        aws_s3_bucket_public_access_block.brainstore,
        aws_s3_bucket_public_access_block.code_bundle_bucket,
        aws_s3_bucket_public_access_block.lambda_responses_bucket,
      ) : [block.block_public_acls, block.block_public_policy, block.ignore_public_acls, block.restrict_public_buckets]
    ]))
    error_message = "All four protections must remain enabled when the module manages them."
  }
}

run "new_deployment_opt_out" {
  command = plan

  module {
    source = "./modules/storage"
  }

  variables {
    manage_s3_public_access_block = false
  }

  assert {
    condition = (
      length(aws_s3_bucket_public_access_block.brainstore) == 0 &&
      length(aws_s3_bucket_public_access_block.code_bundle_bucket) == 0 &&
      length(aws_s3_bucket_public_access_block.lambda_responses_bucket) == 0
    )
    error_message = "Opt-out must omit all storage public access block resources."
  }

  assert {
    condition = (
      length(aws_s3_bucket.brainstore) == 1 &&
      aws_s3_bucket.code_bundle_bucket.bucket_prefix == "bt-test-code-bundles-" &&
      aws_s3_bucket.lambda_responses_bucket.bucket_prefix == "bt-test-lambda-responses-" &&
      length(aws_s3_bucket_policy.brainstore) == 1 &&
      aws_s3_bucket_policy.code_bundle_bucket.policy != null &&
      aws_s3_bucket_policy.lambda_responses_bucket.policy != null &&
      length(aws_s3_bucket_server_side_encryption_configuration.brainstore) == 1 &&
      aws_s3_bucket_server_side_encryption_configuration.code_bundle_bucket.rule != null &&
      aws_s3_bucket_server_side_encryption_configuration.lambda_responses_bucket.rule != null &&
      aws_s3_bucket_versioning.brainstore[0].versioning_configuration[0].status == "Enabled" &&
      aws_s3_bucket_versioning.code_bundle_bucket.versioning_configuration[0].status == "Enabled" &&
      aws_s3_bucket_versioning.lambda_responses_bucket.versioning_configuration[0].status == "Enabled"
    )
    error_message = "Opt-out must preserve buckets, policies, encryption, and versioning."
  }
}

run "external_brainstore_bucket_stays_unmanaged" {
  command = plan

  module {
    source = "./modules/storage"
  }

  variables {
    create_brainstore_s3_bucket       = false
    existing_brainstore_s3_bucket_arn = "arn:aws:s3:::external-brainstore"
  }

  assert {
    condition = (
      length(aws_s3_bucket_public_access_block.brainstore) == 0 &&
      length(aws_s3_bucket_public_access_block.code_bundle_bucket) == 1 &&
      length(aws_s3_bucket_public_access_block.lambda_responses_bucket) == 1
    )
    error_message = "Do not manage protection on a caller-provided Brainstore bucket."
  }
}
