# Verify Brainstore ASG min/max instance count support and that enabling
# autoscaling stops Terraform from managing desired_capacity (so a running
# autoscaler is not scaled back down on every apply).

mock_provider "aws" {
  source = "./tests/mocks/aws"
}

variables {
  deployment_name                       = "bt-test"
  license_key                           = "test-license"
  kms_key_arn                           = "arn:aws:kms:us-east-1:123456789012:key/00000000-0000-0000-0000-000000000000"
  vpc_id                                = "vpc-12345678"
  private_subnet_ids                    = ["subnet-11111111", "subnet-22222222"]
  database_secret_arn                   = "arn:aws:secretsmanager:us-east-1:123456789012:secret:bt-test-database"
  database_host                         = "db.example.internal"
  database_port                         = "5432"
  use_redis_replication_group           = true
  redis_host                            = "redis.example.internal"
  redis_port                            = "6379"
  service_token_secret_arn              = "arn:aws:secretsmanager:us-east-1:123456789012:secret:bt-test-service-token"
  ai_proxy_url_ssm_parameter            = "bt-test-ai-proxy-url"
  brainstore_s3_bucket_arn              = "arn:aws:s3:::bt-test-brainstore"
  lambda_responses_s3_bucket_arn        = "arn:aws:s3:::bt-test-lambda-responses"
  code_bundle_s3_bucket_arn             = "arn:aws:s3:::bt-test-code-bundles"
  brainstore_iam_role_name              = "bt-test-brainstore"
  brainstore_instance_security_group_id = "sg-12345678"
}

# Default sizing: no min/max set. Behavior is unchanged from before this feature:
# a fixed-size ASG with min = desired = instance_count and max = instance_count * 2.
run "fixed_size_defaults" {
  command = plan

  module {
    source = "./modules/brainstore-ec2"
  }

  variables {
    instance_count             = 2
    writer_instance_count      = 0
    fast_reader_instance_count = 0
  }

  assert {
    condition     = aws_autoscaling_group.brainstore.min_size == 2
    error_message = "reader ASG min_size should default to instance_count"
  }

  assert {
    condition     = aws_autoscaling_group.brainstore.max_size == 4
    error_message = "reader ASG max_size should default to instance_count * 2"
  }

  assert {
    condition     = aws_autoscaling_group.brainstore.desired_capacity == 2
    error_message = "reader ASG desired_capacity should be managed (== instance_count) when autoscaling is not enabled"
  }

  assert {
    condition     = aws_autoscaling_group.brainstore.wait_for_elb_capacity == 2
    error_message = "reader ASG wait_for_elb_capacity should equal instance_count when autoscaling is not enabled"
  }
}

# Reader autoscaling: explicit min/max widen the ASG bounds and Terraform stops
# managing desired_capacity so an autoscaler is not reset on every apply.
run "reader_autoscaling_bounds" {
  command = plan

  module {
    source = "./modules/brainstore-ec2"
  }

  variables {
    instance_count             = 2
    min_instance_count         = 3
    max_instance_count         = 10
    writer_instance_count      = 0
    fast_reader_instance_count = 0
  }

  assert {
    condition     = aws_autoscaling_group.brainstore.min_size == 3
    error_message = "reader ASG min_size should follow min_instance_count"
  }

  assert {
    condition     = aws_autoscaling_group.brainstore.max_size == 10
    error_message = "reader ASG max_size should follow max_instance_count"
  }

  assert {
    condition     = aws_autoscaling_group.brainstore.wait_for_elb_capacity == 3
    error_message = "reader ASG wait_for_elb_capacity should equal the min size when autoscaling is enabled"
  }
}

# Only max set: min falls back to instance_count, max is honored, autoscaling on.
run "reader_autoscaling_max_only" {
  command = plan

  module {
    source = "./modules/brainstore-ec2"
  }

  variables {
    instance_count             = 2
    max_instance_count         = 8
    writer_instance_count      = 0
    fast_reader_instance_count = 0
  }

  assert {
    condition     = aws_autoscaling_group.brainstore.min_size == 2
    error_message = "reader ASG min_size should fall back to instance_count when only max is set"
  }

  assert {
    condition     = aws_autoscaling_group.brainstore.max_size == 8
    error_message = "reader ASG max_size should follow max_instance_count when only max is set"
  }
}

# Writer autoscaling behaves the same on the dedicated writer ASG.
run "writer_autoscaling_bounds" {
  command = plan

  module {
    source = "./modules/brainstore-ec2"
  }

  variables {
    instance_count             = 2
    writer_instance_count      = 1
    writer_min_instance_count  = 2
    writer_max_instance_count  = 6
    fast_reader_instance_count = 0
  }

  assert {
    condition     = aws_autoscaling_group.brainstore_writer[0].min_size == 2
    error_message = "writer ASG min_size should follow writer_min_instance_count"
  }

  assert {
    condition     = aws_autoscaling_group.brainstore_writer[0].max_size == 6
    error_message = "writer ASG max_size should follow writer_max_instance_count"
  }
}

# No CPU autoscaling by default: no scaling policies are created.
run "no_cpu_autoscaling_by_default" {
  command = plan

  module {
    source = "./modules/brainstore-ec2"
  }

  variables {
    instance_count             = 2
    writer_instance_count      = 0
    fast_reader_instance_count = 2
  }

  assert {
    condition     = length(aws_autoscaling_policy.brainstore_reader_cpu) == 0
    error_message = "reader CPU scaling policy should not exist unless enabled"
  }

  assert {
    condition     = length(aws_autoscaling_policy.brainstore_fast_reader_cpu) == 0
    error_message = "fast reader CPU scaling policy should not exist unless enabled"
  }
}

# Reader CPU autoscaling: creates a target-tracking policy and puts the ASG into
# autoscaling mode (widened max, min falls back to instance_count).
run "reader_cpu_autoscaling" {
  command = plan

  module {
    source = "./modules/brainstore-ec2"
  }

  variables {
    instance_count                 = 2
    max_instance_count             = 10
    enable_cpu_autoscaling         = true
    cpu_autoscaling_target_percent = 55
    writer_instance_count          = 0
    fast_reader_instance_count     = 0
  }

  assert {
    condition     = length(aws_autoscaling_policy.brainstore_reader_cpu) == 1
    error_message = "reader CPU scaling policy should be created when enabled"
  }

  assert {
    condition     = aws_autoscaling_policy.brainstore_reader_cpu[0].policy_type == "TargetTrackingScaling"
    error_message = "reader CPU scaling policy should be target tracking"
  }

  assert {
    condition     = aws_autoscaling_policy.brainstore_reader_cpu[0].target_tracking_configuration[0].target_value == 55
    error_message = "reader CPU scaling policy should use the configured target"
  }

  assert {
    condition     = aws_autoscaling_policy.brainstore_reader_cpu[0].target_tracking_configuration[0].predefined_metric_specification[0].predefined_metric_type == "ASGAverageCPUUtilization"
    error_message = "reader CPU scaling policy should track average CPU"
  }

  assert {
    condition     = aws_autoscaling_group.brainstore.min_size == 2 && aws_autoscaling_group.brainstore.max_size == 10
    error_message = "enabling CPU autoscaling should honor min/max bounds"
  }
}

# Fast reader CPU autoscaling: policy is created only when fast reader nodes exist.
run "fast_reader_cpu_autoscaling" {
  command = plan

  module {
    source = "./modules/brainstore-ec2"
  }

  variables {
    instance_count                             = 2
    writer_instance_count                      = 0
    fast_reader_instance_count                 = 2
    fast_reader_max_instance_count             = 8
    fast_reader_enable_cpu_autoscaling         = true
    fast_reader_cpu_autoscaling_target_percent = 65
  }

  assert {
    condition     = length(aws_autoscaling_policy.brainstore_fast_reader_cpu) == 1
    error_message = "fast reader CPU scaling policy should be created when enabled and nodes exist"
  }

  assert {
    condition     = aws_autoscaling_policy.brainstore_fast_reader_cpu[0].target_tracking_configuration[0].target_value == 65
    error_message = "fast reader CPU scaling policy should use the configured target"
  }
}

# Fast reader CPU autoscaling is a no-op when there are no fast reader nodes.
run "fast_reader_cpu_autoscaling_requires_nodes" {
  command = plan

  module {
    source = "./modules/brainstore-ec2"
  }

  variables {
    instance_count                     = 2
    writer_instance_count              = 0
    fast_reader_instance_count         = 0
    fast_reader_enable_cpu_autoscaling = true
  }

  assert {
    condition     = length(aws_autoscaling_policy.brainstore_fast_reader_cpu) == 0
    error_message = "fast reader CPU scaling policy should not be created without fast reader nodes"
  }
}
