# Verify opt-in Brainstore reader autoscaling matches the CloudFormation reader
# CPU policy and hands bounds, not a fixed count, to the deployment gate.

mock_provider "aws" {
  source = "./tests/mocks/aws"

  mock_resource "aws_lb" {
    defaults = {
      arn = "arn:aws:elasticloadbalancing:us-east-1:123456789012:loadbalancer/net/bt-reader-scaling/1234567890123456"
    }
  }
  mock_resource "aws_lb_target_group" {
    defaults = {
      arn = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/bt-reader-scaling/1234567890123456"
    }
  }
  mock_resource "aws_iam_instance_profile" {
    defaults = {
      arn = "arn:aws:iam::123456789012:instance-profile/bt-reader-scaling"
    }
  }
  mock_resource "aws_launch_template" {
    defaults = { id = "lt-0123456789abcdef0" }
  }
}

variables {
  deployment_name                       = "bt-reader-scaling"
  license_key_secret_arn                = "arn:aws:secretsmanager:us-east-1:123456789012:secret:license"
  license_key_secret_version            = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
  kms_key_arn                           = "arn:aws:kms:us-east-1:123456789012:key/00000000-0000-0000-0000-000000000000"
  vpc_id                                = "vpc-12345678"
  private_subnet_ids                    = ["subnet-12345678", "subnet-23456789", "subnet-34567890"]
  database_secret_arn                   = "arn:aws:secretsmanager:us-east-1:123456789012:secret:bt-reader-scaling-database"
  database_host                         = "database.example.internal"
  database_port                         = "5432"
  redis_url_secret_arn                  = "arn:aws:secretsmanager:us-east-1:123456789012:secret:bt-reader-scaling-redis-url"
  redis_url_secret_version_id           = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
  service_token_secret_arn              = "arn:aws:secretsmanager:us-east-1:123456789012:secret:bt-reader-scaling-service-token"
  brainstore_s3_bucket_arn              = "arn:aws:s3:::bt-reader-scaling-brainstore"
  lambda_responses_s3_bucket_arn        = "arn:aws:s3:::bt-reader-scaling-lambda-responses"
  code_bundle_s3_bucket_arn             = "arn:aws:s3:::bt-reader-scaling-code-bundles"
  brainstore_iam_role_name              = "bt-reader-scaling-brainstore"
  brainstore_instance_security_group_id = "sg-12345678"
  ai_proxy_url_ssm_parameter            = "/bt-reader-scaling/ai-proxy-url"
}

run "default_reader_pool_stays_fixed" {
  command = plan

  module {
    source = "./modules/brainstore-ec2"
  }

  assert {
    condition = (
      aws_autoscaling_group.brainstore.min_size == 2 &&
      aws_autoscaling_group.brainstore.max_size == 4 &&
      aws_autoscaling_group.brainstore.desired_capacity == 2 &&
      aws_autoscaling_group.brainstore.wait_for_elb_capacity == 2 &&
      length(aws_autoscaling_policy.brainstore_reader_cpu_target) == 0
    )
    error_message = "Without capacity bounds, the reader pool must keep its fixed size and have no scaling policy."
  }

  assert {
    condition = (
      output.deployment_fleets[0].desired_capacity == 2 &&
      output.deployment_fleets[0].min_capacity == null &&
      output.deployment_fleets[0].max_capacity == null
    )
    error_message = "A fixed reader pool must hand its exact desired capacity to the deployment gate."
  }
}

run "reader_autoscaling_sizes_pool_and_gate_from_bounds" {
  command = plan

  module {
    source = "./modules/brainstore-ec2"
  }

  variables {
    reader_min_capacity = 3
    reader_max_capacity = 9
  }

  assert {
    condition = (
      aws_autoscaling_group.brainstore.min_size == 3 &&
      aws_autoscaling_group.brainstore.max_size == 9 &&
      aws_autoscaling_group.brainstore.wait_for_elb_capacity == 3
    )
    error_message = "Reader autoscaling must size the ASG from the configured bounds."
  }

  assert {
    condition = (
      output.deployment_fleets[0].role == "reader" &&
      output.deployment_fleets[0].desired_capacity == null &&
      output.deployment_fleets[0].min_capacity == 3 &&
      output.deployment_fleets[0].max_capacity == 9
    )
    error_message = "An autoscaled reader pool must hand its bounds, not a fixed count, to the deployment gate."
  }
}

run "reader_autoscaling_policy_tracks_cpu" {
  command = apply

  module {
    source = "./modules/brainstore-ec2"
  }

  variables {
    reader_min_capacity           = 2
    reader_max_capacity           = 10
    reader_target_cpu_utilization = 60
  }

  assert {
    condition = (
      aws_autoscaling_policy.brainstore_reader_cpu_target[0].autoscaling_group_name == aws_autoscaling_group.brainstore.name &&
      aws_autoscaling_policy.brainstore_reader_cpu_target[0].policy_type == "TargetTrackingScaling" &&
      aws_autoscaling_policy.brainstore_reader_cpu_target[0].target_tracking_configuration[0].predefined_metric_specification[0].predefined_metric_type == "ASGAverageCPUUtilization" &&
      aws_autoscaling_policy.brainstore_reader_cpu_target[0].target_tracking_configuration[0].target_value == 60 &&
      !aws_autoscaling_policy.brainstore_reader_cpu_target[0].target_tracking_configuration[0].disable_scale_in
    )
    error_message = "The reader policy must track ASG average CPU at the configured target and allow scale-in."
  }
}
