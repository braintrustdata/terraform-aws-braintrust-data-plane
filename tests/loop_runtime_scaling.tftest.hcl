mock_provider "aws" {
  source = "./tests/mocks/aws"
}

variables {
  deployment_name                = "bt-test"
  kms_key_arn                    = "arn:aws:kms:us-east-1:123456789012:key/11111111-1111-1111-1111-111111111111"
  vpc_id                         = "vpc-11111111111111111"
  private_subnet_ids             = ["subnet-11111111111111111", "subnet-22222222222222222"]
  ecs_cluster_arn                = "arn:aws:ecs:us-east-1:123456789012:cluster/bt-test"
  ecs_cluster_name               = "bt-test"
  container_image                = "public.ecr.aws/braintrust/loop-runtime:test"
  target_group_arn               = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/bt-test-loop/1111111111111111"
  alb_security_group_id          = "sg-11111111111111111"
  loop_runtime_http_listener_arn = "arn:aws:elasticloadbalancing:us-east-1:123456789012:listener/app/bt-test-loop/1111111111111111/1111111111111111"
  database_url_secret_arn        = "arn:aws:secretsmanager:us-east-1:123456789012:secret:database"
  redis_url_secret_arn           = "arn:aws:secretsmanager:us-east-1:123456789012:secret:redis"
  function_tools_secret_arn      = "arn:aws:secretsmanager:us-east-1:123456789012:secret:function-tools"
  brainstore_s3_bucket_name      = "bt-test-brainstore"
  brainstore_s3_bucket_arn       = "arn:aws:s3:::bt-test-brainstore"
  code_bundle_bucket             = "bt-test-code-bundles"
  code_bundle_bucket_arn         = "arn:aws:s3:::bt-test-code-bundles"
  brainstore_reader_url          = "http://brainstore.internal:4000"
  ai_proxy_url                   = "https://api.example.com/v1/proxy"
  braintrust_api_url             = "https://api.example.com"
}

run "scales_and_drains_runtime_by_default" {
  command = plan
  module {
    source = "./modules/loop-runtime-ecs"
  }

  assert {
    condition = (
      aws_appautoscaling_policy.loop_runtime_cpu_target.target_tracking_scaling_policy_configuration[0].target_value == 40
      && aws_appautoscaling_policy.loop_runtime_cpu_target.target_tracking_scaling_policy_configuration[0].predefined_metric_specification[0].predefined_metric_type == "ECSServiceAverageCPUUtilization"
      && aws_appautoscaling_policy.loop_runtime_memory_target.target_tracking_scaling_policy_configuration[0].target_value == 50
      && aws_appautoscaling_policy.loop_runtime_memory_target.target_tracking_scaling_policy_configuration[0].predefined_metric_specification[0].predefined_metric_type == "ECSServiceAverageMemoryUtilization"
      && alltrue([
        for policy in [
          aws_appautoscaling_policy.loop_runtime_cpu_target,
          aws_appautoscaling_policy.loop_runtime_memory_target,
          aws_appautoscaling_policy.loop_runtime_conversation_target,
        ] : policy.resource_id == aws_appautoscaling_target.loop_runtime.resource_id
        && policy.target_tracking_scaling_policy_configuration[0].scale_in_cooldown == 120
        && policy.target_tracking_scaling_policy_configuration[0].scale_out_cooldown == 60
        && policy.target_tracking_scaling_policy_configuration[0].disable_scale_in != true
      ])
    )
    error_message = "CPU, memory, and conversation policies must scale the same service with 120/60-second cooldowns and scale-in enabled."
  }

  assert {
    condition = (
      aws_appautoscaling_target.loop_runtime.max_capacity == 50
      && aws_appautoscaling_policy.loop_runtime_conversation_target.target_tracking_scaling_policy_configuration[0].target_value == 50
      && aws_appautoscaling_policy.loop_runtime_conversation_target.target_tracking_scaling_policy_configuration[0].scale_in_cooldown == 120
      && aws_appautoscaling_policy.loop_runtime_conversation_target.target_tracking_scaling_policy_configuration[0].scale_out_cooldown == 60
      && aws_appautoscaling_policy.loop_runtime_conversation_target.target_tracking_scaling_policy_configuration[0].customized_metric_specification[0].namespace == "Braintrust/LoopRuntime"
      && aws_appautoscaling_policy.loop_runtime_conversation_target.target_tracking_scaling_policy_configuration[0].customized_metric_specification[0].metric_name == "ClaimedConversationUtilization"
      && aws_appautoscaling_policy.loop_runtime_conversation_target.target_tracking_scaling_policy_configuration[0].customized_metric_specification[0].statistic == "Average"
      && aws_appautoscaling_policy.loop_runtime_conversation_target.target_tracking_scaling_policy_configuration[0].customized_metric_specification[0].unit == "Percent"
    )
    error_message = "Conversation scaling must target 50% with at most 50 tasks and 120/60-second scale-in/out cooldowns."
  }

  assert {
    condition = (
      {
        for dimension in aws_appautoscaling_policy.loop_runtime_conversation_target.target_tracking_scaling_policy_configuration[0].customized_metric_specification[0].dimensions :
        dimension.name => dimension.value
        } == {
        ClusterName = local.merged_env_vars["LOOP_RUNTIME_CAPACITY_METRIC_CLUSTER_NAME"]
        ServiceName = local.merged_env_vars["LOOP_RUNTIME_CAPACITY_METRIC_SERVICE_NAME"]
      }
      && local.merged_env_vars["LOOP_RUNTIME_CAPACITY_METRIC_NAMESPACE"] == "Braintrust/LoopRuntime"
      && local.merged_env_vars["LOOP_RUNTIME_CAPACITY_METRIC_CLUSTER_NAME"] == var.ecs_cluster_name
      && local.merged_env_vars["LOOP_RUNTIME_CAPACITY_METRIC_SERVICE_NAME"] == aws_ecs_service.loop_runtime.name
    )
    error_message = "Capacity metric environment and scaling policy dimensions must name the same ECS service."
  }

  assert {
    condition = (
      jsondecode(aws_ecs_task_definition.loop_runtime.container_definitions)[0].stopTimeout == 120
      && local.merged_env_vars["LOOP_RUNTIME_DRAIN_TIMEOUT_SECONDS"] == "90"
    )
    error_message = "The runtime must drain for 90 seconds within the container's 120-second stop timeout."
  }
}

run "custom_scaling_keeps_fixed_drain" {
  command = plan
  module {
    source = "./modules/loop-runtime-ecs"
  }
  variables {
    container_image                 = "public.ecr.aws/braintrust/loop-runtime:v1.2.3"
    target_cpu_utilization          = 65
    target_memory_utilization       = 75
    target_conversation_utilization = 70
  }

  assert {
    condition = (
      aws_appautoscaling_policy.loop_runtime_cpu_target.target_tracking_scaling_policy_configuration[0].target_value == 65
      && aws_appautoscaling_policy.loop_runtime_memory_target.target_tracking_scaling_policy_configuration[0].target_value == 75
      && aws_appautoscaling_policy.loop_runtime_conversation_target.target_tracking_scaling_policy_configuration[0].target_value == 70
      && local.merged_env_vars["LOOP_RUNTIME_DRAIN_TIMEOUT_SECONDS"] == "90"
    )
    error_message = "Pinned images must retain CPU and memory scaling alongside conversation scaling, using the supplied targets and a fixed 90-second drain timeout."
  }
}

run "rejects_capacity_metric_override" {
  command = plan
  module {
    source = "./modules/loop-runtime-ecs"
  }
  variables {
    extra_env_vars = {
      LOOP_RUNTIME_CAPACITY_METRIC_SERVICE_NAME = "another-service"
    }
  }
  expect_failures = [var.extra_env_vars]
}

run "rejects_drain_timeout_override" {
  command = plan
  module {
    source = "./modules/loop-runtime-ecs"
  }
  variables {
    extra_env_vars = {
      LOOP_RUNTIME_DRAIN_TIMEOUT_SECONDS = "300"
    }
  }
  expect_failures = [var.extra_env_vars]
}
