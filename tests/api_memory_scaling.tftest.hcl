mock_provider "aws" {
  source = "./tests/mocks/aws"
}

variables {
  deployment_name                       = "bt-test"
  kms_key_arn                           = "arn:aws:kms:us-east-1:123456789012:key/test"
  vpc_id                                = "vpc-0123456789abcdef0"
  private_subnet_ids                    = ["subnet-0123456789abcdef0", "subnet-0123456789abcdef1"]
  ecs_cluster_arn                       = "arn:aws:ecs:us-east-1:123456789012:cluster/bt-test"
  ecs_cluster_name                      = "bt-test"
  braintrust_org_name                   = "test-org"
  database_url_secret_arn               = "arn:aws:secretsmanager:us-east-1:123456789012:secret:database"
  redis_url_secret_arn                  = "arn:aws:secretsmanager:us-east-1:123456789012:secret:redis"
  brainstore_hostname                   = "brainstore.example.internal"
  brainstore_port                       = 9000
  response_bucket                       = "bt-test-responses"
  code_bundle_bucket                    = "bt-test-code"
  function_tools_secret_arn             = "arn:aws:secretsmanager:us-east-1:123456789012:secret:function-tools"
  whitelisted_origins                   = ["https://example.com"]
  outbound_rate_limit_window_minutes    = 1
  outbound_rate_limit_max_requests      = 100
  monitoring_telemetry                  = "true"
  disable_billing_telemetry_aggregation = false
  billing_telemetry_log_level           = "info"
  quarantine_proxy_url                  = ""
  task_role_arn                         = "arn:aws:iam::123456789012:role/api-task"
  task_security_group_id                = "sg-0123456789abcdef0"

  braintrust_api_cpu_autoscaling = {
    target_value       = 70
    scale_in_cooldown  = 60
    scale_out_cooldown = 60
  }
  braintrust_api_memory_autoscaling = {
    target_value       = 75
    scale_in_cooldown  = 60
    scale_out_cooldown = 60
  }
  braintrust_api_event_loop_utilization_autoscaling = {
    target_value       = 70
    scale_in_cooldown  = 60
    scale_out_cooldown = 60
  }
  braintrust_api_event_loop_delay_autoscaling = {
    evaluation_periods = 1
    period             = 60
    cooldown           = 60
    steps              = [{ threshold_ms = 100, scaling_adjustment = 1 }]
  }
  braintrust_api_ingest_cpu_autoscaling = {
    target_value       = 70
    scale_in_cooldown  = 60
    scale_out_cooldown = 60
  }
  braintrust_api_ingest_memory_autoscaling = {
    target_value       = 75
    scale_in_cooldown  = 60
    scale_out_cooldown = 60
  }
  braintrust_api_ingest_event_loop_utilization_autoscaling = {
    target_value       = 70
    scale_in_cooldown  = 60
    scale_out_cooldown = 60
  }
  braintrust_api_ingest_event_loop_delay_autoscaling = {
    evaluation_periods = 1
    period             = 60
    cooldown           = 60
    steps              = [{ threshold_ms = 100, scaling_adjustment = 1 }]
  }
  braintrust_api_background_cpu_autoscaling = {
    target_value       = 70
    scale_in_cooldown  = 60
    scale_out_cooldown = 60
  }
  braintrust_api_background_memory_autoscaling = {
    target_value       = 75
    scale_in_cooldown  = 60
    scale_out_cooldown = 60
  }
  braintrust_api_background_event_loop_utilization_autoscaling = {
    target_value       = 70
    scale_in_cooldown  = 60
    scale_out_cooldown = 60
  }
  braintrust_api_background_event_loop_delay_autoscaling = {
    evaluation_periods = 1
    period             = 60
    cooldown           = 60
    steps              = [{ threshold_ms = 100, scaling_adjustment = 1 }]
  }
}

run "api_services_scale_on_memory" {
  command = plan
  module {
    source = "./modules/api-ecs"
  }

  assert {
    condition = (
      aws_appautoscaling_policy.braintrust_api_memory_target.resource_id == aws_appautoscaling_target.braintrust_api.resource_id
      && aws_appautoscaling_policy.braintrust_api_memory_target.target_tracking_scaling_policy_configuration[0].predefined_metric_specification[0].predefined_metric_type == "ECSServiceAverageMemoryUtilization"
      && aws_appautoscaling_policy.braintrust_api_memory_target.target_tracking_scaling_policy_configuration[0].target_value == 75
      && aws_appautoscaling_policy.braintrust_api_memory_target.target_tracking_scaling_policy_configuration[0].scale_in_cooldown == 60
      && aws_appautoscaling_policy.braintrust_api_memory_target.target_tracking_scaling_policy_configuration[0].scale_out_cooldown == 60
      && aws_appautoscaling_policy.braintrust_api_memory_target.target_tracking_scaling_policy_configuration[0].disable_scale_in != true
    )
    error_message = "Memory scaling must use the service's existing target, configured utilization and cooldowns, with scale-in enabled."
  }

  assert {
    condition = (
      aws_appautoscaling_policy.braintrust_api_ingest_memory_target.resource_id == aws_appautoscaling_target.braintrust_api_ingest.resource_id
      && aws_appautoscaling_policy.braintrust_api_ingest_memory_target.target_tracking_scaling_policy_configuration[0].predefined_metric_specification[0].predefined_metric_type == "ECSServiceAverageMemoryUtilization"
      && aws_appautoscaling_policy.braintrust_api_ingest_memory_target.target_tracking_scaling_policy_configuration[0].target_value == 75
      && aws_appautoscaling_policy.braintrust_api_ingest_memory_target.target_tracking_scaling_policy_configuration[0].scale_in_cooldown == 60
      && aws_appautoscaling_policy.braintrust_api_ingest_memory_target.target_tracking_scaling_policy_configuration[0].scale_out_cooldown == 60
      && aws_appautoscaling_policy.braintrust_api_ingest_memory_target.target_tracking_scaling_policy_configuration[0].disable_scale_in != true
    )
    error_message = "Memory scaling must use the service's existing target, configured utilization and cooldowns, with scale-in enabled."
  }

  assert {
    condition = (
      aws_appautoscaling_policy.braintrust_api_background_memory_target.resource_id == aws_appautoscaling_target.braintrust_api_background.resource_id
      && aws_appautoscaling_policy.braintrust_api_background_memory_target.target_tracking_scaling_policy_configuration[0].predefined_metric_specification[0].predefined_metric_type == "ECSServiceAverageMemoryUtilization"
      && aws_appautoscaling_policy.braintrust_api_background_memory_target.target_tracking_scaling_policy_configuration[0].target_value == 75
      && aws_appautoscaling_policy.braintrust_api_background_memory_target.target_tracking_scaling_policy_configuration[0].scale_in_cooldown == 60
      && aws_appautoscaling_policy.braintrust_api_background_memory_target.target_tracking_scaling_policy_configuration[0].scale_out_cooldown == 60
      && aws_appautoscaling_policy.braintrust_api_background_memory_target.target_tracking_scaling_policy_configuration[0].disable_scale_in != true
    )
    error_message = "Memory scaling must use the service's existing target, configured utilization and cooldowns, with scale-in enabled."
  }
}

run "rejects_braintrust_api_invalid_memory_target" {
  command = plan
  module { source = "./modules/api-ecs" }
  variables {
    braintrust_api_memory_autoscaling = {
      target_value       = 101
      scale_in_cooldown  = 300
      scale_out_cooldown = 60
    }
  }

  expect_failures = [var.braintrust_api_memory_autoscaling]
}

run "rejects_braintrust_api_ingest_invalid_memory_target" {
  command = plan
  module { source = "./modules/api-ecs" }
  variables {
    braintrust_api_ingest_memory_autoscaling = {
      target_value       = 101
      scale_in_cooldown  = 300
      scale_out_cooldown = 60
    }
  }

  expect_failures = [var.braintrust_api_ingest_memory_autoscaling]
}

run "rejects_braintrust_api_background_invalid_memory_target" {
  command = plan
  module { source = "./modules/api-ecs" }
  variables {
    braintrust_api_background_memory_autoscaling = {
      target_value       = 101
      scale_in_cooldown  = 300
      scale_out_cooldown = 60
    }
  }

  expect_failures = [var.braintrust_api_background_memory_autoscaling]
}
