# Verify version_override pins every Brainstore node type and wins over
# per-node-type overrides, and that per-node-type overrides apply only to their
# own node type.

mock_provider "aws" {
  source = "./tests/mocks/aws"

  mock_resource "aws_lb" {
    defaults = {
      arn = "arn:aws:elasticloadbalancing:us-east-1:123456789012:loadbalancer/net/bt-version/1234567890123456"
    }
  }
  mock_resource "aws_lb_target_group" {
    defaults = {
      arn = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/bt-version/1234567890123456"
    }
  }
  mock_resource "aws_iam_instance_profile" {
    defaults = {
      arn = "arn:aws:iam::123456789012:instance-profile/bt-version"
    }
  }
  mock_resource "aws_launch_template" {
    defaults = { id = "lt-0123456789abcdef0" }
  }
}

variables {
  deployment_name                       = "bt-version"
  license_key_secret_arn                = "arn:aws:secretsmanager:us-east-1:123456789012:secret:bt-version-license"
  license_key_secret_version            = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
  kms_key_arn                           = "arn:aws:kms:us-east-1:123456789012:key/00000000-0000-0000-0000-000000000000"
  vpc_id                                = "vpc-12345678"
  private_subnet_ids                    = ["subnet-12345678", "subnet-23456789", "subnet-34567890"]
  database_secret_arn                   = "arn:aws:secretsmanager:us-east-1:123456789012:secret:bt-version-database"
  database_host                         = "database.example.internal"
  database_port                         = "5432"
  redis_url_secret_arn                  = "arn:aws:secretsmanager:us-east-1:123456789012:secret:bt-version-redis-url"
  redis_url_secret_version_id           = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
  service_token_secret_arn              = "arn:aws:secretsmanager:us-east-1:123456789012:secret:bt-version-service-token"
  brainstore_s3_bucket_arn              = "arn:aws:s3:::bt-version-brainstore"
  lambda_responses_s3_bucket_arn        = "arn:aws:s3:::bt-version-lambda-responses"
  code_bundle_s3_bucket_arn             = "arn:aws:s3:::bt-version-code-bundles"
  brainstore_iam_role_name              = "bt-version-brainstore"
  brainstore_instance_security_group_id = "sg-12345678"
  ai_proxy_url_ssm_parameter            = "/bt-version/ai-proxy-url"
  writer_instance_count                 = 1
  fast_reader_instance_count            = 1
  automation_writer_instance_count      = 1
}

run "no_overrides_use_release_version" {
  command = plan

  module {
    source = "./modules/brainstore-ec2"
  }

  assert {
    condition = (
      local.brainstore_reader_version_override == "" &&
      local.brainstore_writer_version_override == "" &&
      local.brainstore_fast_reader_version_override == "" &&
      local.brainstore_automation_writer_version_override == ""
    )
    error_message = "Without overrides every node type must fall back to the release version."
  }
}

run "per_node_type_overrides_apply_to_their_node_type" {
  command = plan

  module {
    source = "./modules/brainstore-ec2"
  }

  variables {
    reader_version_override            = "reader-tag"
    writer_version_override            = "writer-tag"
    fast_reader_version_override       = "fast-reader-tag"
    automation_writer_version_override = "automation-writer-tag"
  }

  assert {
    condition = (
      local.brainstore_reader_version_override == "reader-tag" &&
      local.brainstore_writer_version_override == "writer-tag" &&
      local.brainstore_fast_reader_version_override == "fast-reader-tag" &&
      local.brainstore_automation_writer_version_override == "automation-writer-tag"
    )
    error_message = "Each per-node-type override must apply only to its own node type."
  }
}

run "single_node_type_override_leaves_others_on_release_version" {
  command = plan

  module {
    source = "./modules/brainstore-ec2"
  }

  variables {
    writer_version_override = "writer-tag"
  }

  assert {
    condition = (
      local.brainstore_reader_version_override == "" &&
      local.brainstore_writer_version_override == "writer-tag" &&
      local.brainstore_fast_reader_version_override == "" &&
      local.brainstore_automation_writer_version_override == ""
    )
    error_message = "A writer override must not change the other node types."
  }
}

run "global_override_wins" {
  command = plan

  module {
    source = "./modules/brainstore-ec2"
  }

  variables {
    version_override                   = "global-tag"
    reader_version_override            = "reader-tag"
    writer_version_override            = "writer-tag"
    fast_reader_version_override       = "fast-reader-tag"
    automation_writer_version_override = "automation-writer-tag"
  }

  assert {
    condition = (
      local.brainstore_reader_version_override == "global-tag" &&
      local.brainstore_writer_version_override == "global-tag" &&
      local.brainstore_fast_reader_version_override == "global-tag" &&
      local.brainstore_automation_writer_version_override == "global-tag"
    )
    error_message = "version_override must win over every per-node-type override."
  }
}

run "empty_global_override_does_not_block_node_type_override" {
  command = plan

  module {
    source = "./modules/brainstore-ec2"
  }

  variables {
    version_override        = ""
    writer_version_override = "writer-tag"
  }

  assert {
    condition = (
      local.brainstore_reader_version_override == "" &&
      local.brainstore_writer_version_override == "writer-tag" &&
      local.brainstore_fast_reader_version_override == "" &&
      local.brainstore_automation_writer_version_override == ""
    )
    error_message = "An empty version_override must be treated as unset so node-type overrides still apply."
  }
}

run "rejects_empty_per_node_type_overrides" {
  command = plan

  module {
    source = "./modules/brainstore-ec2"
  }

  variables {
    reader_version_override            = ""
    writer_version_override            = ""
    fast_reader_version_override       = ""
    automation_writer_version_override = ""
  }

  expect_failures = [
    var.reader_version_override,
    var.writer_version_override,
    var.fast_reader_version_override,
    var.automation_writer_version_override,
  ]
}
