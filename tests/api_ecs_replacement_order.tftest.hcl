# Replacement-order regression fixture for all fixed-name API ECS services.

mock_provider "aws" {
  source = "./tests/mocks/aws"
}

override_resource {
  target = aws_iam_role.task_execution
  values = {
    arn  = "arn:aws:iam::123456789012:role/bt-test-api-task-exec"
    id   = "bt-test-api-task-exec"
    name = "bt-test-api-task-exec"
  }
}

override_resource {
  target = aws_lb.api_ecs
  values = {
    arn        = "arn:aws:elasticloadbalancing:us-east-1:123456789012:loadbalancer/app/bt-test-api/test"
    arn_suffix = "app/bt-test-api/test"
    dns_name   = "bt-test-api.us-east-1.elb.amazonaws.com"
    id         = "arn:aws:elasticloadbalancing:us-east-1:123456789012:loadbalancer/app/bt-test-api/test"
    zone_id    = "Z35SXDOTRQ7X7K"
  }
}

override_resource {
  target = aws_lb_listener.api_ecs_http
  values = {
    arn = "arn:aws:elasticloadbalancing:us-east-1:123456789012:listener/app/bt-test-api/1234567890abcdef/1234567890abcdef"
    id  = "arn:aws:elasticloadbalancing:us-east-1:123456789012:listener/app/bt-test-api/1234567890abcdef/1234567890abcdef"
  }
}

override_resource {
  target = aws_lb_target_group.braintrust_api
  values = {
    arn        = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/braintrust-api/test"
    arn_suffix = "targetgroup/braintrust-api/test"
  }
}

override_resource {
  target = aws_lb_target_group.braintrust_api_ingest
  values = {
    arn        = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/braintrust-api-ingest/test"
    arn_suffix = "targetgroup/braintrust-api-ingest/test"
  }
}

override_resource {
  target = aws_lb_target_group.braintrust_api_background
  values = {
    arn        = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/braintrust-api-background/test"
    arn_suffix = "targetgroup/braintrust-api-background/test"
  }
}

override_resource {
  target = aws_appautoscaling_policy.braintrust_api_event_loop_delay_step
  values = {
    arn = "arn:aws:sns:us-east-1:123456789012:braintrust-api-scale"
  }
}

override_resource {
  target = aws_appautoscaling_policy.braintrust_api_ingest_event_loop_delay_step
  values = {
    arn = "arn:aws:sns:us-east-1:123456789012:braintrust-api-ingest-scale"
  }
}

override_resource {
  target = aws_appautoscaling_policy.braintrust_api_background_event_loop_delay_step
  values = {
    arn = "arn:aws:sns:us-east-1:123456789012:braintrust-api-background-scale"
  }
}

override_resource {
  target = aws_ecs_task_definition.braintrust_api
  values = {
    arn      = "arn:aws:ecs:us-east-1:123456789012:task-definition/bt-test-braintrust-api:1"
    family   = "bt-test-braintrust-api"
    revision = 1
  }
}

override_resource {
  target = aws_ecs_task_definition.braintrust_api_ingest
  values = {
    arn      = "arn:aws:ecs:us-east-1:123456789012:task-definition/bt-test-braintrust-api-ingest:1"
    family   = "bt-test-braintrust-api-ingest"
    revision = 1
  }
}

override_resource {
  target = aws_ecs_task_definition.braintrust_api_background
  values = {
    arn      = "arn:aws:ecs:us-east-1:123456789012:task-definition/bt-test-braintrust-api-background:1"
    family   = "bt-test-braintrust-api-background"
    revision = 1
  }
}

variables {
  deployment_name      = "bt-test"
  kms_key_arn          = "arn:aws:kms:us-east-1:123456789012:key/test"
  vpc_id               = "vpc-test"
  private_subnet_ids   = ["subnet-a", "subnet-b"]
  ecs_cluster_arn      = "arn:aws:ecs:us-east-1:123456789012:cluster/bt-test"
  ecs_cluster_name     = "bt-test"
  api_version_override = "test"

  braintrust_org_name    = "test-org"
  primary_org_name       = "test-org"
  brainstore_license_key = "test-license"

  database_url_secret_arn   = "arn:aws:secretsmanager:us-east-1:123456789012:secret:database"
  redis_url_secret_arn      = "arn:aws:secretsmanager:us-east-1:123456789012:secret:redis"
  function_tools_secret_arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:function-tools"
  response_bucket           = "responses-test"
  code_bundle_bucket        = "code-bundle-test"

  brainstore_hostname             = "brainstore.test"
  brainstore_writer_hostname      = "brainstore-writer.test"
  brainstore_fast_reader_hostname = "brainstore-fast-reader.test"
  brainstore_s3_bucket_name       = "brainstore-test"
  brainstore_port                 = 4000
  brainstore_etl_batch_size       = 100

  whitelisted_origins                   = ["https://www.braintrust.dev"]
  outbound_rate_limit_window_minutes    = 1
  outbound_rate_limit_max_requests      = 100
  monitoring_telemetry                  = "status,metrics"
  disable_billing_telemetry_aggregation = false
  billing_telemetry_log_level           = "info"
  quarantine_proxy_url                  = "https://ai-proxy.test"
  task_role_arn                         = "arn:aws:iam::123456789012:role/bt-test-api-task"
  task_security_group_id                = "sg-api"

  braintrust_api_cpu_autoscaling = {
    target_value       = 50
    scale_in_cooldown  = 60
    scale_out_cooldown = 60
  }
  braintrust_api_event_loop_utilization_autoscaling = {
    target_value       = 50
    scale_in_cooldown  = 60
    scale_out_cooldown = 60
  }
  braintrust_api_event_loop_delay_autoscaling = {
    evaluation_periods = 1
    period             = 60
    cooldown           = 60
    steps = [{
      threshold_ms       = 10
      scaling_adjustment = 10
    }]
  }

  braintrust_api_ingest_cpu_autoscaling = {
    target_value       = 50
    scale_in_cooldown  = 60
    scale_out_cooldown = 60
  }
  braintrust_api_ingest_event_loop_utilization_autoscaling = {
    target_value       = 50
    scale_in_cooldown  = 60
    scale_out_cooldown = 60
  }
  braintrust_api_ingest_event_loop_delay_autoscaling = {
    evaluation_periods = 1
    period             = 60
    cooldown           = 60
    steps = [{
      threshold_ms       = 10
      scaling_adjustment = 10
    }]
  }

  braintrust_api_background_cpu_autoscaling = {
    target_value       = 50
    scale_in_cooldown  = 60
    scale_out_cooldown = 60
  }
  braintrust_api_background_event_loop_utilization_autoscaling = {
    target_value       = 50
    scale_in_cooldown  = 60
    scale_out_cooldown = 60
  }
  braintrust_api_background_event_loop_delay_autoscaling = {
    evaluation_periods = 1
    period             = 60
    cooldown           = 60
    steps = [{
      threshold_ms       = 10
      scaling_adjustment = 10
    }]
  }
}

run "seed_mocked_api_ecs_state" {
  command = apply

  module {
    source = "./modules/api-ecs"
  }
}

run "force_fixed_name_api_ecs_replacements" {
  command = plan

  module {
    source = "./modules/api-ecs"
  }

  plan_options {
    refresh = false
    replace = [
      aws_ecs_service.braintrust_api,
      aws_ecs_service.braintrust_api_ingest,
      aws_ecs_service.braintrust_api_background,
    ]
  }
}
