mock_provider "aws" {
  source = "./tests/mocks/aws"

  mock_resource "aws_lb" {
    defaults = {
      arn = "arn:aws:elasticloadbalancing:us-east-1:123456789012:loadbalancer/app/api/1111111111111111"
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

run "function_invocations_route_to_background_api" {
  command = apply

  plan_options {
    target = [aws_lb_listener_rule.alb_path_routes]
  }

  module {
    source = "./modules/api-ecs"
  }

  variables {
    brainstore_license_key_secret_arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:license"
  }

  override_resource {
    target = aws_lb_target_group.braintrust_api_background
    values = {
      arn = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/background/4444444444444444"
    }
  }

  assert {
    condition = alltrue([
      for key in ["POST:/function/invoke", "POST:/v1/function/*/invoke"] :
      contains(keys(aws_lb_listener_rule.alb_path_routes), key)
      && one(aws_lb_listener_rule.alb_path_routes[key].action[0].forward[0].target_group).arn == aws_lb_target_group.braintrust_api_background.arn
    ])
    error_message = "POST function invocations must route to the background API."
  }
}

run "private_function_invocations_route_to_background_api" {
  command = apply

  plan_options {
    target = [aws_lb_listener_rule.alb_path_routes, aws_lb_listener_rule.alb_internal_path_routes]
  }

  module {
    source = "./modules/api-ecs"
  }

  variables {
    brainstore_license_key_secret_arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:license"

    enable_private_dataplane = true
  }

  override_resource {
    target = aws_lb_target_group.braintrust_api_background
    values = {
      arn = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/background/4444444444444444"
    }
  }

  assert {
    condition = alltrue([
      for key in ["POST:/function/invoke", "POST:/v1/function/*/invoke"] :
      one(aws_lb_listener_rule.alb_path_routes[key].action[0].forward[0].target_group).arn == aws_lb_target_group.braintrust_api_background.arn
      && aws_lb_listener_rule.alb_internal_path_routes[key].action[0].target_group_arn == aws_lb_target_group.braintrust_api_background.arn
    ])
    error_message = "Both private listeners must route POST function invocations to the background API."
  }
}
