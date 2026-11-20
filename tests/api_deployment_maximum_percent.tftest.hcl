# The API ECS services expose deployment_maximum_percent per service. The
# default stays at 200. Callers can lower it to limit extra Fargate tasks
# during a rolling deployment.

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
  redis_url_secret_version_id           = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
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

run "api_services_default_deployment_maximum_percent" {
  command = plan
  module { source = "./modules/api-ecs" }
  variables {
    brainstore_license_key_secret_arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:license"
  }

  assert {
    condition = (
      aws_ecs_service.braintrust_api.deployment_maximum_percent == 200
      && aws_ecs_service.braintrust_api_ingest.deployment_maximum_percent == 200
      && aws_ecs_service.braintrust_api_background.deployment_maximum_percent == 200
    )
    error_message = "API ECS services must keep deployment_maximum_percent at 200 by default."
  }
}

run "api_services_custom_deployment_maximum_percent" {
  command = plan
  module { source = "./modules/api-ecs" }
  variables {
    brainstore_license_key_secret_arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:license"

    braintrust_api_deployment_maximum_percent            = 150
    braintrust_api_ingest_deployment_maximum_percent     = 120
    braintrust_api_background_deployment_maximum_percent = 134
  }

  assert {
    condition     = aws_ecs_service.braintrust_api.deployment_maximum_percent == 150
    error_message = "braintrust-api must use braintrust_api_deployment_maximum_percent."
  }

  assert {
    condition     = aws_ecs_service.braintrust_api_ingest.deployment_maximum_percent == 120
    error_message = "braintrust-api-ingest must use braintrust_api_ingest_deployment_maximum_percent."
  }

  assert {
    condition     = aws_ecs_service.braintrust_api_background.deployment_maximum_percent == 134
    error_message = "braintrust-api-background must use braintrust_api_background_deployment_maximum_percent."
  }
}

run "rejects_deployment_maximum_percent_above_200" {
  command = plan
  module { source = "./modules/api-ecs" }
  variables {
    brainstore_license_key_secret_arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:license"

    braintrust_api_deployment_maximum_percent = 201
  }

  expect_failures = [var.braintrust_api_deployment_maximum_percent]
}

run "rejects_deployment_maximum_percent_at_100" {
  command = plan
  module { source = "./modules/api-ecs" }
  variables {
    brainstore_license_key_secret_arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:license"

    braintrust_api_ingest_deployment_maximum_percent = 100
  }

  expect_failures = [var.braintrust_api_ingest_deployment_maximum_percent]
}

# Background defaults to 3 tasks. floor(3 * 133 / 100) = 3, so ECS could not
# start a replacement task while minimum healthy percent stays at 100.
run "rejects_deployment_maximum_percent_without_extra_task" {
  command = plan
  module { source = "./modules/api-ecs" }
  variables {
    brainstore_license_key_secret_arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:license"

    braintrust_api_background_deployment_maximum_percent = 133
  }

  expect_failures = [var.braintrust_api_background_deployment_maximum_percent]
}
