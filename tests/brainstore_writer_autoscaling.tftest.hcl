# Verify opt-in Brainstore writer autoscaling matches the CloudFormation writer
# policies, and that the default fixed-size writer pool is unchanged.

mock_provider "aws" {
  source = "./tests/mocks/aws"

  mock_resource "aws_lb" {
    defaults = {
      arn = "arn:aws:elasticloadbalancing:us-east-1:123456789012:loadbalancer/net/bt-writer-scaling/1234567890123456"
    }
  }
  mock_resource "aws_lb_target_group" {
    defaults = {
      arn = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/bt-writer-scaling/1234567890123456"
    }
  }
  mock_resource "aws_iam_instance_profile" {
    defaults = {
      arn = "arn:aws:iam::123456789012:instance-profile/bt-writer-scaling"
    }
  }
  mock_resource "aws_launch_template" {
    defaults = { id = "lt-0123456789abcdef0" }
  }
}

variables {
  deployment_name                       = "bt-writer-scaling"
  license_key_secret_arn                = "arn:aws:secretsmanager:us-east-1:123456789012:secret:license"
  license_key_secret_version            = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
  kms_key_arn                           = "arn:aws:kms:us-east-1:123456789012:key/00000000-0000-0000-0000-000000000000"
  vpc_id                                = "vpc-12345678"
  private_subnet_ids                    = ["subnet-12345678", "subnet-23456789", "subnet-34567890"]
  database_secret_arn                   = "arn:aws:secretsmanager:us-east-1:123456789012:secret:bt-writer-scaling-database"
  database_host                         = "database.example.internal"
  database_port                         = "5432"
  redis_url_secret_arn                  = "arn:aws:secretsmanager:us-east-1:123456789012:secret:bt-writer-scaling-redis-url"
  redis_url_secret_version_id           = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
  service_token_secret_arn              = "arn:aws:secretsmanager:us-east-1:123456789012:secret:bt-writer-scaling-service-token"
  brainstore_s3_bucket_arn              = "arn:aws:s3:::bt-writer-scaling-brainstore"
  lambda_responses_s3_bucket_arn        = "arn:aws:s3:::bt-writer-scaling-lambda-responses"
  code_bundle_s3_bucket_arn             = "arn:aws:s3:::bt-writer-scaling-code-bundles"
  brainstore_iam_role_name              = "bt-writer-scaling-brainstore"
  brainstore_instance_security_group_id = "sg-12345678"
  ai_proxy_url_ssm_parameter            = "/bt-writer-scaling/ai-proxy-url"
  writer_instance_count                 = 3
}

run "default_writer_pool_stays_fixed" {
  command = plan

  module {
    source = "./modules/brainstore-ec2"
  }

  assert {
    condition = (
      aws_autoscaling_group.brainstore_writer[0].min_size == 3 &&
      aws_autoscaling_group.brainstore_writer[0].max_size == 6 &&
      aws_autoscaling_group.brainstore_writer[0].desired_capacity == 3 &&
      aws_autoscaling_group.brainstore_writer[0].wait_for_elb_capacity == 3 &&
      length(aws_autoscaling_policy.brainstore_writer_compaction_queue_target) == 0 &&
      length(aws_autoscaling_policy.brainstore_writer_merge_loop_segments_target) == 0
    )
    error_message = "Without capacity bounds, the writer pool must keep its fixed size and have no scaling policies."
  }
}

run "writer_autoscaling_sizes_pool_from_bounds" {
  command = plan

  module {
    source = "./modules/brainstore-ec2"
  }

  variables {
    writer_min_capacity = 2
    writer_max_capacity = 8
  }

  assert {
    condition = (
      aws_autoscaling_group.brainstore_writer[0].min_size == 2 &&
      aws_autoscaling_group.brainstore_writer[0].max_size == 8 &&
      aws_autoscaling_group.brainstore_writer[0].wait_for_elb_capacity == 2
    )
    error_message = "Writer autoscaling must size the ASG from the configured bounds."
  }
}

run "writer_autoscaling_policies_track_backfill_metrics" {
  command = apply

  module {
    source = "./modules/brainstore-ec2"
  }

  variables {
    writer_min_capacity                 = 2
    writer_max_capacity                 = 8
    writer_target_compaction_queue_size = 20
  }

  assert {
    condition = alltrue([
      for policy in [
        aws_autoscaling_policy.brainstore_writer_compaction_queue_target[0],
        aws_autoscaling_policy.brainstore_writer_merge_loop_segments_target[0]
      ] :
      policy.autoscaling_group_name == aws_autoscaling_group.brainstore_writer[0].name &&
      policy.policy_type == "TargetTrackingScaling" &&
      !policy.target_tracking_configuration[0].disable_scale_in &&
      policy.target_tracking_configuration[0].customized_metric_specification[0].namespace == "CWAgent" &&
      policy.target_tracking_configuration[0].customized_metric_specification[0].statistic == "Average" &&
      policy.target_tracking_configuration[0].customized_metric_specification[0].metric_dimension == tolist([{
        name  = "AutoScalingGroupName"
        value = aws_autoscaling_group.brainstore_writer[0].name
      }])
    ])
    error_message = "Both writer policies must track the writer ASG's ASG-only CWAgent series and allow scale-in."
  }

  assert {
    condition = (
      aws_autoscaling_policy.brainstore_writer_compaction_queue_target[0].target_tracking_configuration[0].customized_metric_specification[0].metric_name == "brainstore_backfill_compaction_queue_size" &&
      aws_autoscaling_policy.brainstore_writer_compaction_queue_target[0].target_tracking_configuration[0].target_value == 20 &&
      aws_autoscaling_policy.brainstore_writer_merge_loop_segments_target[0].target_tracking_configuration[0].customized_metric_specification[0].metric_name == "brainstore_backfill_merge_loop_segments" &&
      aws_autoscaling_policy.brainstore_writer_merge_loop_segments_target[0].target_tracking_configuration[0].target_value == 400
    )
    error_message = "Writer policies must track the CloudFormation backfill metrics with configured or default targets."
  }
}

run "writer_autoscaling_ignored_without_writer_pool" {
  command = plan

  module {
    source = "./modules/brainstore-ec2"
  }

  variables {
    writer_instance_count = 0
  }

  assert {
    condition = (
      length(aws_autoscaling_group.brainstore_writer) == 0 &&
      length(aws_autoscaling_policy.brainstore_writer_compaction_queue_target) == 0 &&
      length(aws_autoscaling_policy.brainstore_writer_merge_loop_segments_target) == 0
    )
    error_message = "A disabled writer pool must not create writer scaling policies."
  }
}

run "writer_autoscaling_rejects_bounds_without_writer_pool" {
  command = plan

  module {
    source = "./modules/brainstore-ec2"
  }

  variables {
    writer_instance_count = 0
    writer_min_capacity   = 1
    writer_max_capacity   = 4
  }

  expect_failures = [var.writer_max_capacity]
}
