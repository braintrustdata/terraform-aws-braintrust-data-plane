mock_provider "aws" {
  source = "./tests/mocks/aws"
}

variables {
  deployment_name = "bt-test"
}

run "checkpoints_have_deployment_storage_lifetime" {
  command = apply
  module {
    source = "./modules/storage"
  }
  assert {
    condition = (
      !aws_s3_bucket.sandbox_filesystems.force_destroy &&
      aws_s3_bucket_public_access_block.sandbox_filesystems[0].block_public_policy &&
      one([for rule in aws_s3_bucket_lifecycle_configuration.sandbox_filesystems.rule : rule if rule.id == "ExpireSandboxCheckpoints"]).filter[0].prefix == "sandbox-filesystems/sandbox-checkpoints-v1/" &&
      one([for rule in aws_s3_bucket_lifecycle_configuration.sandbox_filesystems.rule : rule if rule.id == "ExpireSandboxCheckpoints"]).expiration[0].days == 14 &&
      output.sandbox_filesystems_bucket_id == aws_s3_bucket.sandbox_filesystems.id
    )
    error_message = "Deployment storage must own a protected checkpoint bucket with expiration limited to checkpoint objects."
  }
}

run "retention_override_and_bucket_controls" {
  command = apply
  module {
    source = "./modules/storage"
  }
  variables {
    sandbox_checkpoint_retention_days = 30
    manage_s3_public_access_block     = false
    enable_s3_bucket_abac             = true
    kms_key_arn                       = "arn:aws:kms:us-east-1:123456789012:key/checkpoints"
  }
  assert {
    condition = (
      one([for rule in aws_s3_bucket_lifecycle_configuration.sandbox_filesystems.rule : rule if rule.id == "ExpireSandboxCheckpoints"]).expiration[0].days == 30 &&
      length(aws_s3_bucket_public_access_block.sandbox_filesystems) == 0 &&
      aws_s3_bucket_abac.sandbox_filesystems[0].abac_status[0].status == "Enabled" &&
      one(aws_s3_bucket_server_side_encryption_configuration.sandbox_filesystems.rule).apply_server_side_encryption_by_default[0].kms_master_key_id == var.kms_key_arn
    )
    error_message = "Checkpoint storage must honor retention and existing storage ownership controls."
  }
}

run "rejects_invalid_checkpoint_retention" {
  command = plan
  module {
    source = "./modules/storage"
  }
  variables {
    sandbox_checkpoint_retention_days = 0
  }
  expect_failures = [var.sandbox_checkpoint_retention_days]
}
