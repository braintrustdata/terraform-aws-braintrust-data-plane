mock_provider "aws" {
  source = "./tests/mocks/aws"
}

variables {
  brainstore_license_key                    = "test-license"
  internal_observability_api_key_secret_arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:observability"
  deployment_name                           = "bt-test"
  kms_key_arn                               = "arn:aws:kms:us-east-1:123456789012:key/test"
  vpc_id                                    = "vpc-0123456789abcdef0"
  private_subnet_ids                        = ["subnet-0123456789abcdef0", "subnet-0123456789abcdef1"]
  ecs_cluster_arn                           = "arn:aws:ecs:us-east-1:123456789012:cluster/bt-test"
  ecs_cluster_name                          = "bt-test"
  braintrust_org_name                       = "test-org"
  database_url_secret_arn                   = "arn:aws:secretsmanager:us-east-1:123456789012:secret:database"
  redis_url_secret_arn                      = "arn:aws:secretsmanager:us-east-1:123456789012:secret:redis"
  brainstore_hostname                       = "brainstore.example.internal"
  brainstore_port                           = 9000
  response_bucket                           = "bt-test-responses"
  code_bundle_bucket                        = "bt-test-code"
  function_tools_secret_arn                 = "arn:aws:secretsmanager:us-east-1:123456789012:secret:function-tools"
  whitelisted_origins                       = ["https://example.com"]
  outbound_rate_limit_window_minutes        = 1
  outbound_rate_limit_max_requests          = 100
  monitoring_telemetry                      = "true"
  disable_billing_telemetry_aggregation     = false
  billing_telemetry_log_level               = "info"
  quarantine_proxy_url                      = ""
  task_role_arn                             = "arn:aws:iam::123456789012:role/api-task"
  task_security_group_id                    = "sg-0123456789abcdef0"

  braintrust_api_cpu_autoscaling = {
    target_value       = 70
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

run "pulse_logs_off" {
  command = plan
  module {
    source = "./modules/api-ecs"
  }
  assert {
    condition = alltrue([
      for task in [aws_ecs_task_definition.braintrust_api, aws_ecs_task_definition.braintrust_api_ingest, aws_ecs_task_definition.braintrust_api_background] :
      sort([for container in jsondecode(task.container_definitions) : container.name]) == sort(["api", "datadog-agent", "log-router"]) &&
      one([for container in jsondecode(task.container_definitions) : container if container.name == "api"]).logConfiguration.logDriver == "awsfirelens" &&
      sort([for dependency in one([for container in jsondecode(task.container_definitions) : container if container.name == "api"]).dependsOn : dependency.containerName]) == sort(["datadog-agent", "log-router"])
    ])
    error_message = "API log drivers, sidecars, and startup dependencies must agree on the selected log export path."
  }
}

run "pulse_logs_on" {
  command = plan
  module {
    source = "./modules/api-ecs"
  }
  variables {
    monitoring_telemetry = "status,metrics,logs"
  }
  assert {
    condition = alltrue([
      for task in [aws_ecs_task_definition.braintrust_api, aws_ecs_task_definition.braintrust_api_ingest, aws_ecs_task_definition.braintrust_api_background] :
      sort([for container in jsondecode(task.container_definitions) : container.name]) == sort(["api", "datadog-agent"]) &&
      one([for container in jsondecode(task.container_definitions) : container if container.name == "api"]).logConfiguration.logDriver == "awslogs" &&
      sort([for dependency in one([for container in jsondecode(task.container_definitions) : container if container.name == "api"]).dependsOn : dependency.containerName]) == sort(["datadog-agent"])
    ])
    error_message = "API log drivers, sidecars, and startup dependencies must agree on the selected log export path."
  }
}

run "pulse_logs_enabled_by_override" {
  command = plan
  module {
    source = "./modules/api-ecs"
  }
  variables {
    extra_env_vars = { CONTROL_PLANE_TELEMETRY = "all" }
  }
  assert {
    condition = alltrue([
      for task in [aws_ecs_task_definition.braintrust_api, aws_ecs_task_definition.braintrust_api_ingest, aws_ecs_task_definition.braintrust_api_background] :
      sort([for container in jsondecode(task.container_definitions) : container.name]) == sort(["api", "datadog-agent"]) &&
      one([for container in jsondecode(task.container_definitions) : container if container.name == "api"]).logConfiguration.logDriver == "awslogs" &&
      sort([for dependency in one([for container in jsondecode(task.container_definitions) : container if container.name == "api"]).dependsOn : dependency.containerName]) == sort(["datadog-agent"])
    ])
    error_message = "API log drivers, sidecars, and startup dependencies must agree on the selected log export path."
  }
}

run "pulse_logs_disabled_by_override" {
  command = plan
  module {
    source = "./modules/api-ecs"
  }
  variables {
    monitoring_telemetry = "logs"
    extra_env_vars       = { CONTROL_PLANE_TELEMETRY = "" }
  }
  assert {
    condition = alltrue([
      for task in [aws_ecs_task_definition.braintrust_api, aws_ecs_task_definition.braintrust_api_ingest, aws_ecs_task_definition.braintrust_api_background] :
      sort([for container in jsondecode(task.container_definitions) : container.name]) == sort(["api", "datadog-agent", "log-router"]) &&
      one([for container in jsondecode(task.container_definitions) : container if container.name == "api"]).logConfiguration.logDriver == "awsfirelens" &&
      sort([for dependency in one([for container in jsondecode(task.container_definitions) : container if container.name == "api"]).dependsOn : dependency.containerName]) == sort(["datadog-agent", "log-router"])
    ])
    error_message = "API log drivers, sidecars, and startup dependencies must agree on the selected log export path."
  }
}

run "internal_observability_off" {
  command = plan
  module {
    source = "./modules/api-ecs"
  }
  variables {
    monitoring_telemetry                      = "logs"
    internal_observability_api_key_secret_arn = ""
  }
  assert {
    condition = alltrue([
      for task in [aws_ecs_task_definition.braintrust_api, aws_ecs_task_definition.braintrust_api_ingest, aws_ecs_task_definition.braintrust_api_background] :
      sort([for container in jsondecode(task.container_definitions) : container.name]) == sort(["api"]) &&
      one([for container in jsondecode(task.container_definitions) : container if container.name == "api"]).logConfiguration.logDriver == "awslogs" &&
      sort([for dependency in one([for container in jsondecode(task.container_definitions) : container if container.name == "api"]).dependsOn : dependency.containerName]) == sort([])
    ])
    error_message = "API log drivers, sidecars, and startup dependencies must agree on the selected log export path."
  }
}


run "pulse_logs_without_license" {
  command = plan
  module {
    source = "./modules/api-ecs"
  }
  variables {
    monitoring_telemetry   = "logs"
    brainstore_license_key = null
  }
  assert {
    condition = alltrue([
      for task in [aws_ecs_task_definition.braintrust_api, aws_ecs_task_definition.braintrust_api_ingest, aws_ecs_task_definition.braintrust_api_background] :
      sort([for container in jsondecode(task.container_definitions) : container.name]) == sort(["api", "datadog-agent", "log-router"]) &&
      one([for container in jsondecode(task.container_definitions) : container if container.name == "api"]).logConfiguration.logDriver == "awsfirelens" &&
      sort([for dependency in one([for container in jsondecode(task.container_definitions) : container if container.name == "api"]).dependsOn : dependency.containerName]) == sort(["datadog-agent", "log-router"])
    ])
    error_message = "API log drivers, sidecars, and startup dependencies must agree on the selected log export path."
  }
}

run "pulse_logs_with_empty_license" {
  command = plan
  module {
    source = "./modules/api-ecs"
  }
  variables {
    monitoring_telemetry   = "logs"
    brainstore_license_key = ""
  }
  assert {
    condition = alltrue([
      for task in [aws_ecs_task_definition.braintrust_api, aws_ecs_task_definition.braintrust_api_ingest, aws_ecs_task_definition.braintrust_api_background] :
      sort([for container in jsondecode(task.container_definitions) : container.name]) == sort(["api", "datadog-agent", "log-router"]) &&
      one([for container in jsondecode(task.container_definitions) : container if container.name == "api"]).logConfiguration.logDriver == "awsfirelens" &&
      sort([for dependency in one([for container in jsondecode(task.container_definitions) : container if container.name == "api"]).dependsOn : dependency.containerName]) == sort(["datadog-agent", "log-router"])
    ])
    error_message = "API log drivers, sidecars, and startup dependencies must agree on the selected log export path."
  }
}
