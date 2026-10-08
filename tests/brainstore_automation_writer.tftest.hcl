# Verify disabled automation writers skip instance metadata and enabled pools
# retain their cache sizing and distinct writer-loop configuration.

mock_provider "aws" {
  source = "./tests/mocks/aws"
}

variables {
  deployment_name                       = "bt-automation-writer"
  license_key                           = "test-license"
  kms_key_arn                           = "arn:aws:kms:us-east-1:123456789012:key/00000000-0000-0000-0000-000000000000"
  vpc_id                                = "vpc-12345678"
  private_subnet_ids                    = ["subnet-12345678", "subnet-23456789", "subnet-34567890"]
  database_secret_arn                   = "arn:aws:secretsmanager:us-east-1:123456789012:secret:bt-automation-writer-database"
  database_host                         = "database.example.internal"
  database_port                         = "5432"
  use_redis_replication_group           = true
  redis_host                            = "redis.example.internal"
  redis_port                            = "6379"
  service_token_secret_arn              = "arn:aws:secretsmanager:us-east-1:123456789012:secret:bt-automation-writer-service-token"
  brainstore_s3_bucket_arn              = "arn:aws:s3:::bt-automation-writer-brainstore"
  lambda_responses_s3_bucket_arn        = "arn:aws:s3:::bt-automation-writer-lambda-responses"
  code_bundle_s3_bucket_arn             = "arn:aws:s3:::bt-automation-writer-code-bundles"
  brainstore_iam_role_name              = "bt-automation-writer-brainstore"
  brainstore_instance_security_group_id = "sg-12345678"
  ai_proxy_url_ssm_parameter            = "/bt-automation-writer/ai-proxy-url"
  automation_writer_instance_count      = 1
}

run "disabled_automation_writer_skips_instance_metadata" {
  command = plan

  module {
    source = "./modules/brainstore-ec2"
  }

  variables {
    automation_writer_instance_count = 0
    automation_writer_instance_type  = "unused-instance-type"
  }

  assert {
    condition = (
      length(data.aws_ec2_instance_type.brainstore_automation_writer) == 0 &&
      local.brainstore_automation_writer_cache_file_size == null &&
      length(aws_launch_template.brainstore_automation_writer) == 0 &&
      length(aws_autoscaling_group.brainstore_automation_writer) == 0
    )
    error_message = "A disabled automation writer pool must not look up its instance type, calculate its cache, or create nodes."
  }
}

run "automation_writer_loop_config_is_rendered" {
  command = plan

  module {
    source = "./modules/brainstore-ec2"
  }

  variables {
    fast_reader_instance_count = 1
  }

  assert {
    condition = (
      aws_launch_template.brainstore_writer[0].user_data != aws_launch_template.brainstore_automation_writer[0].user_data &&
      aws_autoscaling_group.brainstore_automation_writer[0].min_size == 1 &&
      aws_autoscaling_group.brainstore_automation_writer[0].max_size == 1 &&
      aws_autoscaling_group.brainstore_automation_writer[0].health_check_type == "EBS"
    )
    error_message = "AutomationWriter should be a fixed-size ASG with no load-balancer target group"
  }

  assert {
    condition = (
      length(data.aws_ec2_instance_type.brainstore_automation_writer) == 1 &&
      local.brainstore_automation_writer_cache_file_size == "712gb" &&
      aws_launch_template.brainstore_automation_writer[0].instance_type == var.automation_writer_instance_type
    )
    error_message = "An enabled automation writer pool must look up its configured instance type and use 75% of its local storage for the cache."
  }

  assert {
    condition = (
      local.brainstore_writer_cache_file_size == "712gb" &&
      local.brainstore_automation_writer_cache_file_size == "712gb"
    )
    error_message = "Both writer pools must receive a cache size of 75% of their local storage, rounded down to whole GB."
  }

  assert {
    condition = (
      local.brainstore_cache_file_size == "855gb" &&
      local.brainstore_fast_reader_cache_file_size == "855gb"
    )
    error_message = "Both reader pools must receive a cache size of 90% of their local storage."
  }
}

run "automation_writer_preserves_cache_override" {
  command = plan

  module {
    source = "./modules/brainstore-ec2"
  }

  variables {
    cache_file_size_automation_writer = "100gb"
  }

  assert {
    condition = (
      length(data.aws_ec2_instance_type.brainstore_automation_writer) == 1 &&
      local.brainstore_automation_writer_cache_file_size == "100gb"
    )
    error_message = "An enabled automation writer pool must preserve an explicit cache size while still validating its instance storage."
  }
}

run "automation_writer_requires_local_storage_with_cache_override" {
  command = plan

  module {
    source = "./modules/brainstore-ec2"
  }

  variables {
    cache_file_size_automation_writer = "100gb"
  }

  override_data {
    target = data.aws_ec2_instance_type.brainstore_automation_writer[0]
    values = {
      total_instance_storage = null
    }
  }

  expect_failures = [data.aws_ec2_instance_type.brainstore_automation_writer[0]]
}
