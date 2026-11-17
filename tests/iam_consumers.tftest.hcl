# Each module that used to create its own IAM role now takes the role's ARN as
# an input. These runs check that the module uses the ARN it was given, so
# the readiness edge on modules/iam's output reaches the resource that needs it.
# The database can't run as the module under test, because its sensitive
# outputs need a root module to mark them. scripts/check-iam-dependencies checks
# its wiring through the graph.

mock_provider "aws" {
  source = "./tests/mocks/aws"
}

mock_provider "http" {
  source = "./tests/mocks/http"
}

run "brainstore_waiter_runs_as_the_supplied_role" {
  command = plan
  module { source = "./modules/brainstore-deployment" }

  variables {
    deployment_name = "bt-test"
    version_tag     = "test-api-version"
    waiter_role_arn = "arn:aws:iam::123456789012:role/bt-test-brainstore-deployment"
    fleets          = []
  }

  assert {
    condition     = aws_lambda_function.waiter.role == "arn:aws:iam::123456789012:role/bt-test-brainstore-deployment"
    error_message = "The waiter function must run as the supplied role."
  }
}

run "gateway_tasks_run_as_the_supplied_roles" {
  command = plan
  module { source = "./modules/gateway-ecs" }

  variables {
    deployment_name                   = "bt-test"
    kms_key_arn                       = "arn:aws:kms:us-east-1:123456789012:key/test"
    task_execution_role_arn           = "arn:aws:iam::123456789012:role/bt-test-gateway-task-exec"
    task_role_arn                     = "arn:aws:iam::123456789012:role/bt-test-gateway-task"
    vpc_id                            = "vpc-0123456789abcdef0"
    private_subnet_ids                = ["subnet-0123456789abcdef0", "subnet-0123456789abcdef1"]
    ecs_cluster_arn                   = "arn:aws:ecs:us-east-1:123456789012:cluster/bt-test"
    ecs_cluster_name                  = "bt-test"
    container_image                   = "public.ecr.aws/braintrust/gateway:test"
    target_group_arn                  = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/gateway/1234567890123456"
    alb_security_group_id             = "sg-0123456789abcdef2"
    gateway_http_listener_arn         = "arn:aws:elasticloadbalancing:us-east-1:123456789012:listener/app/gateway/1234567890123456/1234567890123456"
    gateway_url                       = "http://gateway.internal"
    braintrust_api_url                = "http://api.internal"
    redis_url_secret_arn              = "arn:aws:secretsmanager:us-east-1:123456789012:secret:redis"
    redis_url_secret_version_id       = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
    redis_port                        = 6379
    redis_security_group_id           = "sg-0123456789abcdef1"
    brainstore_license_key_secret_arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:license"
  }

  assert {
    condition     = aws_ecs_task_definition.gateway.execution_role_arn == "arn:aws:iam::123456789012:role/bt-test-gateway-task-exec" && aws_ecs_task_definition.gateway.task_role_arn == "arn:aws:iam::123456789012:role/bt-test-gateway-task"
    error_message = "The gateway task definition must use the supplied execution and task roles."
  }
}

run "api_task_definitions_start_with_the_supplied_execution_role" {
  command = plan
  module { source = "./modules/api-ecs" }

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
    task_execution_role_arn               = "arn:aws:iam::123456789012:role/bt-test-api-ecs-task-exec"
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

    brainstore_license_key_secret_arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:license"
  }

  assert {
    condition = alltrue([
      for task in [aws_ecs_task_definition.braintrust_api, aws_ecs_task_definition.braintrust_api_ingest, aws_ecs_task_definition.braintrust_api_background] :
      task.execution_role_arn == "arn:aws:iam::123456789012:role/bt-test-api-ecs-task-exec" && task.task_role_arn == "arn:aws:iam::123456789012:role/api-task"
    ])
    error_message = "Every API task definition must use the supplied execution role and keep the shared task role."
  }
}
