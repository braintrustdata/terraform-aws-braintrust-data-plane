mock_provider "aws" {
  source = "./tests/mocks/aws"

  mock_resource "aws_iam_instance_profile" {
    defaults = {
      arn = "arn:aws:iam::123456789012:instance-profile/test-brainstore"
    }
  }

  mock_resource "aws_lb" {
    defaults = {
      arn = "arn:aws:elasticloadbalancing:us-east-1:123456789012:loadbalancer/net/test/1234567890123456"
    }
  }

  mock_resource "aws_lb_target_group" {
    defaults = {
      arn = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/test/1234567890123456"
    }
  }

  mock_resource "aws_launch_template" {
    defaults = {
      id             = "lt-0123456789abcdef0"
      latest_version = 42
    }
  }
}

variables {
  deployment_name                       = "bt-test"
  license_key                           = "test-license"
  kms_key_arn                           = null
  vpc_id                                = "vpc-12345678"
  private_subnet_ids                    = ["subnet-12345678"]
  database_secret_arn                   = "arn:aws:secretsmanager:us-east-1:123456789012:secret:database-test"
  database_host                         = "database.example.com"
  database_port                         = "5432"
  use_redis_replication_group           = false
  redis_host                            = "redis.example.com"
  redis_port                            = "6379"
  service_token_secret_arn              = "arn:aws:secretsmanager:us-east-1:123456789012:secret:token-test"
  ai_proxy_url_ssm_parameter            = "/bt-test/ai-proxy-url"
  brainstore_s3_bucket_arn              = "arn:aws:s3:::test-brainstore"
  lambda_responses_s3_bucket_arn        = "arn:aws:s3:::test-responses"
  code_bundle_s3_bucket_arn             = "arn:aws:s3:::test-code"
  brainstore_iam_role_name              = "bt-test-brainstore"
  brainstore_instance_security_group_id = "sg-12345678"
  writer_instance_count                 = 1
  fast_reader_instance_count            = 1
}

run "default_tracks_latest_template" {
  command = apply
  module { source = "./modules/brainstore-ec2" }

  assert {
    condition     = aws_autoscaling_group.brainstore.launch_template[0].version == "42" && output.deployment_fleets[0].launch_template_version == "42"
    error_message = "The default reader ASG and deployment controller must both use the latest template."
  }
}

run "pinned_reader_preserves_other_fleets" {
  command = apply
  module { source = "./modules/brainstore-ec2" }

  variables {
    reader_launch_template_version = 41
  }

  assert {
    condition     = aws_autoscaling_group.brainstore.launch_template[0].version == "41" && output.deployment_fleets[0].launch_template_version == "41"
    error_message = "The reader ASG and deployment controller must both honor the selected template."
  }

  assert {
    condition     = aws_autoscaling_group.brainstore_writer[0].launch_template[0].version == "42" && aws_autoscaling_group.brainstore_fast_reader[0].launch_template[0].version == "42" && output.deployment_fleets[1].launch_template_version == "42"
    error_message = "Pinning the regular reader must not alter the writer or fast-reader templates."
  }

  assert {
    condition     = length(aws_autoscaling_group.brainstore.instance_refresh) == 0
    error_message = "Selecting a reader template must not add an automatic ASG instance refresh."
  }
}

run "reject_zero_template_version" {
  command = plan
  module { source = "./modules/brainstore-ec2" }

  variables {
    reader_launch_template_version = 0
  }

  expect_failures = [var.reader_launch_template_version]
}
