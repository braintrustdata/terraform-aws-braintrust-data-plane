mock_provider "aws" {
  source = "./tests/mocks/aws"

  mock_resource "aws_lb" {
    defaults = {
      arn = "arn:aws:elasticloadbalancing:us-east-1:123456789012:loadbalancer/app/api/1111111111111111"
    }
  }

  mock_resource "aws_iam_role" {
    defaults = {
      arn = "arn:aws:iam::123456789012:role/api-execution"
    }
  }

  mock_resource "aws_ecs_task_definition" {
    defaults = {
      arn = "arn:aws:ecs:us-east-1:123456789012:task-definition/api:1"
    }
  }

  mock_resource "aws_appautoscaling_policy" {
    defaults = {
      arn = "arn:aws:autoscaling:us-east-1:123456789012:scalingPolicy:11111111-1111-1111-1111-111111111111:resource/ecs/service/bt-test/api:policyName/test"
    }
  }

  mock_resource "aws_lb_target_group" {
    defaults = {
      arn = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/api/1111111111111111"
    }
  }

  mock_resource "aws_lb_listener" {
    defaults = {
      arn = "arn:aws:elasticloadbalancing:us-east-1:123456789012:listener/app/api/1111111111111111/2222222222222222"
    }
  }
}

override_resource {
  target = aws_lb_target_group.braintrust_api_background
  values = {
    arn = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/background/3333333333333333"
  }
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
  redis_url_secret_version_id           = "11111111-1111-1111-1111-111111111111"
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

run "voice_disabled_by_default" {
  command = plan
  module { source = "./modules/api-ecs" }
  variables {
    brainstore_license_key_secret_arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:license"
  }
  assert {
    condition = (
      !contains(keys(aws_lb_listener_rule.alb_path_routes), "POST:/v1/project/*/simulated_user/*/session")
      && !contains(keys(aws_lb_listener_rule.alb_path_routes), "GET:/v1/voice_session/*/connect")
      && length(aws_appautoscaling_policy.braintrust_api_background_voice_slots) == 0
      && alltrue([for container in jsondecode(aws_ecs_task_definition.braintrust_api_background.container_definitions) : !contains([for env in container.environment : env.name], "VOICE_SESSION_WS_BASE_URL") if container.name == "api"])
    )
    error_message = "The default must omit voice routes, configuration, and occupancy scaling."
  }
}

run "voice_uses_background_pool" {
  command = apply
  module { source = "./modules/api-ecs" }
  variables {
    brainstore_license_key_secret_arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:license"
    enable_ecs_voice_sessions         = true
    voice_session_ws_base_url         = "wss://api.example.com"
    extra_env_vars                    = { WEB_CONCURRENCY = "2" }
  }
  assert {
    condition = alltrue([
      for key in ["POST:/v1/project/*/simulated_user/*/session", "GET:/v1/voice_session/*/connect"] : (
        one(aws_lb_listener_rule.alb_path_routes[key].action[0].forward[0].target_group).arn == aws_lb_target_group.braintrust_api_background.arn
        && one([for condition in aws_lb_listener_rule.alb_path_routes[key].condition : one(condition.http_request_method).values if length(condition.http_request_method) > 0]) == toset([split(":", key)[0]])
      )
    ])
    error_message = "Both method-specific voice routes must use the existing background target group."
  }
  assert {
    condition = alltrue([
      for container in jsondecode(aws_ecs_task_definition.braintrust_api_background.container_definitions) : (
        container.stopTimeout == 120
        && one([for env in container.environment : env.value if env.name == "VOICE_SESSION_WS_BASE_URL"]) == "wss://api.example.com"
        && one([for env in container.environment : env.value if env.name == "WEB_CONCURRENCY"]) == "2"
      ) if container.name == "api"
    ])
    error_message = "Background workers need the public WebSocket origin, normal worker count, and time to finalize recordings."
  }
  assert {
    condition = alltrue([
      for definition in [aws_ecs_task_definition.braintrust_api.container_definitions, aws_ecs_task_definition.braintrust_api_ingest.container_definitions] :
      alltrue([for container in jsondecode(definition) : !contains([for env in container.environment : env.name], "VOICE_SESSION_WS_BASE_URL") if container.name == "api"])
    ])
    error_message = "Other API pools must not enable hosted voice sessions."
  }
  assert {
    condition = (
      aws_appautoscaling_policy.braintrust_api_background_voice_slots[0].resource_id == aws_appautoscaling_target.braintrust_api_background.resource_id
      && aws_appautoscaling_policy.braintrust_api_background_voice_slots[0].target_tracking_scaling_policy_configuration[0].target_value == 60
      && aws_appautoscaling_policy.braintrust_api_background_voice_slots[0].target_tracking_scaling_policy_configuration[0].scale_in_cooldown == 300
      && aws_appautoscaling_policy.braintrust_api_background_voice_slots[0].target_tracking_scaling_policy_configuration[0].scale_out_cooldown == 60
      && aws_appautoscaling_policy.braintrust_api_background_voice_slots[0].target_tracking_scaling_policy_configuration[0].customized_metric_specification[0].metric_name == "VoiceSlotUtilizationPercent"
      && aws_appautoscaling_policy.braintrust_api_background_voice_slots[0].target_tracking_scaling_policy_configuration[0].customized_metric_specification[0].namespace == "Braintrust/Api"
      && aws_appautoscaling_policy.braintrust_api_background_voice_slots[0].target_tracking_scaling_policy_configuration[0].customized_metric_specification[0].dimensions == toset([
        { name = "ServiceName", value = "braintrust-api-background" },
        { name = "DeploymentName", value = "bt-test" },
      ])
    )
    error_message = "Voice occupancy must scale the shared pool using the API's service and deployment metric dimensions."
  }
}

run "private_voice_routes_reach_both_listeners" {
  command = apply
  module { source = "./modules/api-ecs" }
  variables {
    brainstore_license_key_secret_arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:license"
    enable_ecs_voice_sessions         = true
    voice_session_ws_base_url         = "wss://api.example.internal"
    enable_private_dataplane          = true
    alb_custom_domain                 = "api.example.internal"
    alb_certificate_arn               = "arn:aws:acm:us-east-1:123456789012:certificate/11111111-1111-1111-1111-111111111111"
  }
  assert {
    condition = alltrue([
      for key in ["POST:/v1/project/*/simulated_user/*/session", "GET:/v1/voice_session/*/connect"] : (
        aws_lb_listener_rule.alb_internal_path_routes[key].condition == aws_lb_listener_rule.alb_path_routes[key].condition
        && aws_lb_listener_rule.alb_internal_path_routes[key].action[0].target_group_arn == aws_lb_target_group.braintrust_api_background.arn
      )
    ])
    error_message = "Private customer and callback listeners must preserve both voice routes and their methods."
  }
}

run "disabling_voice_removes_routes_and_configuration" {
  command = apply
  module { source = "./modules/api-ecs" }
  variables {
    brainstore_license_key_secret_arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:license"
  }
  assert {
    condition = (
      length(aws_lb_listener_rule.alb_path_routes) == 21
      && length(aws_lb_listener_rule.alb_internal_path_routes) == 0
      && length(aws_appautoscaling_policy.braintrust_api_background_voice_slots) == 0
      && alltrue([for container in jsondecode(aws_ecs_task_definition.braintrust_api_background.container_definitions) : !contains([for env in container.environment : env.name], "VOICE_SESSION_WS_BASE_URL") if container.name == "api"])
    )
    error_message = "Disabling voice must remove its routing, admission configuration, and scaling policy in one apply."
  }
}

run "rejects_voice_without_websocket_origin" {
  command = plan
  module { source = "./modules/api-ecs" }
  variables {
    brainstore_license_key_secret_arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:license"
    enable_ecs_voice_sessions         = true
  }
  expect_failures = [var.voice_session_ws_base_url]
}
