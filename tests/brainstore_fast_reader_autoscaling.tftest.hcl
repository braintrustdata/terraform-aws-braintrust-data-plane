# Verify opt-in Brainstore fast reader autoscaling matches the CloudFormation fast
# reader CPU policy and hands bounds, not a fixed count, to the deployment gate.

mock_provider "aws" {
  source = "./tests/mocks/aws"

  mock_resource "aws_lb" {
    defaults = {
      arn = "arn:aws:elasticloadbalancing:us-east-1:123456789012:loadbalancer/net/bt-fr-scaling/1234567890123456"
    }
  }
  mock_resource "aws_lb_target_group" {
    defaults = {
      arn = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/bt-fr-scaling/1234567890123456"
    }
  }
  mock_resource "aws_iam_instance_profile" {
    defaults = {
      arn = "arn:aws:iam::123456789012:instance-profile/bt-fr-scaling"
    }
  }
  mock_resource "aws_launch_template" {
    defaults = { id = "lt-0123456789abcdef0" }
  }
}

variables {
  deployment_name                       = "bt-fr-scaling"
  license_key_secret_arn                = "arn:aws:secretsmanager:us-east-1:123456789012:secret:license"
  license_key_secret_version            = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
  kms_key_arn                           = "arn:aws:kms:us-east-1:123456789012:key/00000000-0000-0000-0000-000000000000"
  vpc_id                                = "vpc-12345678"
  private_subnet_ids                    = ["subnet-12345678", "subnet-23456789", "subnet-34567890"]
  database_secret_arn                   = "arn:aws:secretsmanager:us-east-1:123456789012:secret:bt-fr-scaling-database"
  database_host                         = "database.example.internal"
  database_port                         = "5432"
  redis_url_secret_arn                  = "arn:aws:secretsmanager:us-east-1:123456789012:secret:bt-fr-scaling-redis-url"
  redis_url_secret_version_id           = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
  service_token_secret_arn              = "arn:aws:secretsmanager:us-east-1:123456789012:secret:bt-fr-scaling-service-token"
  brainstore_s3_bucket_arn              = "arn:aws:s3:::bt-fr-scaling-brainstore"
  lambda_responses_s3_bucket_arn        = "arn:aws:s3:::bt-fr-scaling-lambda-responses"
  code_bundle_s3_bucket_arn             = "arn:aws:s3:::bt-fr-scaling-code-bundles"
  brainstore_iam_role_name              = "bt-fr-scaling-brainstore"
  brainstore_instance_security_group_id = "sg-12345678"
  ai_proxy_url_ssm_parameter            = "/bt-fr-scaling/ai-proxy-url"
  fast_reader_instance_count            = 2
}

run "default_fast_reader_pool_stays_fixed" {
  command = plan

  module {
    source = "./modules/brainstore-ec2"
  }

  assert {
    condition = (
      aws_autoscaling_group.brainstore_fast_reader[0].min_size == 2 &&
      aws_autoscaling_group.brainstore_fast_reader[0].max_size == 4 &&
      aws_autoscaling_group.brainstore_fast_reader[0].desired_capacity == 2 &&
      aws_autoscaling_group.brainstore_fast_reader[0].wait_for_elb_capacity == 2 &&
      length(aws_autoscaling_policy.brainstore_fast_reader_cpu_target) == 0
    )
    error_message = "Without capacity bounds, the fast reader pool must keep its fixed size and have no scaling policy."
  }

  assert {
    condition = (
      output.deployment_fleets[1].role == "fast-reader" &&
      output.deployment_fleets[1].desired_capacity == 2 &&
      output.deployment_fleets[1].min_capacity == null &&
      output.deployment_fleets[1].max_capacity == null
    )
    error_message = "A fixed fast reader pool must hand its exact desired capacity to the deployment gate."
  }
}

run "fast_reader_autoscaling_sizes_pool_and_gate_from_bounds" {
  command = plan

  module {
    source = "./modules/brainstore-ec2"
  }

  variables {
    fast_reader_min_capacity = 2
    fast_reader_max_capacity = 8
  }

  assert {
    condition = (
      aws_autoscaling_group.brainstore_fast_reader[0].min_size == 2 &&
      aws_autoscaling_group.brainstore_fast_reader[0].max_size == 8 &&
      aws_autoscaling_group.brainstore_fast_reader[0].wait_for_elb_capacity == 2
    )
    error_message = "Fast reader autoscaling must size the ASG from the configured bounds."
  }

  assert {
    condition = (
      output.deployment_fleets[1].role == "fast-reader" &&
      output.deployment_fleets[1].desired_capacity == null &&
      output.deployment_fleets[1].min_capacity == 2 &&
      output.deployment_fleets[1].max_capacity == 8 &&
      output.deployment_fleets[0].desired_capacity == 2
    )
    error_message = "An autoscaled fast reader pool must hand its bounds to the gate without changing the reader fleet."
  }
}

run "fast_reader_autoscaling_policy_tracks_cpu" {
  command = apply

  module {
    source = "./modules/brainstore-ec2"
  }

  variables {
    fast_reader_min_capacity           = 2
    fast_reader_max_capacity           = 8
    fast_reader_target_cpu_utilization = 65
  }

  assert {
    condition = (
      aws_autoscaling_policy.brainstore_fast_reader_cpu_target[0].autoscaling_group_name == aws_autoscaling_group.brainstore_fast_reader[0].name &&
      aws_autoscaling_policy.brainstore_fast_reader_cpu_target[0].policy_type == "TargetTrackingScaling" &&
      aws_autoscaling_policy.brainstore_fast_reader_cpu_target[0].target_tracking_configuration[0].predefined_metric_specification[0].predefined_metric_type == "ASGAverageCPUUtilization" &&
      aws_autoscaling_policy.brainstore_fast_reader_cpu_target[0].target_tracking_configuration[0].target_value == 65 &&
      !aws_autoscaling_policy.brainstore_fast_reader_cpu_target[0].target_tracking_configuration[0].disable_scale_in
    )
    error_message = "The fast reader policy must track ASG average CPU at the configured target and allow scale-in."
  }
}

run "fast_reader_autoscaling_rejects_bounds_without_pool" {
  command = plan

  module {
    source = "./modules/brainstore-ec2"
  }

  variables {
    fast_reader_instance_count = 0
    fast_reader_min_capacity   = 1
    fast_reader_max_capacity   = 4
  }

  expect_failures = [var.fast_reader_max_capacity]
}
