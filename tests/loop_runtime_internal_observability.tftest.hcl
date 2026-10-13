# The internal Datadog agent skips the Loop telemetry that the effective
# BRAINSTORE_CONTROL_PLANE_TELEMETRY (Pulse) already carries.

mock_provider "aws" {
  source = "./tests/mocks/aws"
}

variables {
  deployment_name                           = "bt-test"
  kms_key_arn                               = "arn:aws:kms:us-east-1:123456789012:key/11111111-1111-1111-1111-111111111111"
  vpc_id                                    = "vpc-11111111111111111"
  private_subnet_ids                        = ["subnet-11111111111111111", "subnet-22222222222222222"]
  ecs_cluster_arn                           = "arn:aws:ecs:us-east-1:123456789012:cluster/bt-test"
  ecs_cluster_name                          = "bt-test"
  container_image                           = "public.ecr.aws/braintrust/loop-runtime:test"
  target_group_arn                          = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/bt-test-loop/1111111111111111"
  alb_security_group_id                     = "sg-11111111111111111"
  loop_runtime_http_listener_arn            = "arn:aws:elasticloadbalancing:us-east-1:123456789012:listener/app/bt-test-loop/1111111111111111/1111111111111111"
  sandbox_egress_gateway_target_group_arn   = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/bt-test-loop-egress/2222222222222222"
  database_url_secret_arn                   = "arn:aws:secretsmanager:us-east-1:123456789012:secret:database"
  redis_url_secret_arn                      = "arn:aws:secretsmanager:us-east-1:123456789012:secret:redis"
  function_tools_secret_arn                 = "arn:aws:secretsmanager:us-east-1:123456789012:secret:function-tools"
  brainstore_s3_bucket_name                 = "bt-test-brainstore"
  brainstore_s3_bucket_arn                  = "arn:aws:s3:::bt-test-brainstore"
  code_bundle_bucket                        = "bt-test-code-bundles"
  code_bundle_bucket_arn                    = "arn:aws:s3:::bt-test-code-bundles"
  brainstore_reader_url                     = "http://brainstore.internal:4000"
  ai_proxy_url                              = "https://api.example.com/v1/proxy"
  braintrust_api_url                        = "https://api.example.com"
  internal_observability_enabled            = true
  internal_observability_api_key_secret_arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:datadog"
  internal_observability_env_name           = "test"
  internal_observability_region             = "us5"
  monitoring_telemetry                      = "status,metrics,usage,memprof,traces,logs"
}

run "pulse_off_keeps_datadog_agent_path" {
  command = plan

  module {
    source = "./modules/loop-runtime-ecs"
  }

  variables {
    extra_env_vars = { BRAINSTORE_CONTROL_PLANE_TELEMETRY = "" }
  }

  assert {
    condition = (
      contains(jsondecode(aws_ecs_task_definition.loop_runtime.container_definitions)[0].environment, { name = "BRAINSTORE_OTLP_HTTP_ENDPOINT", value = "http://localhost:4318" }) &&
      contains(jsondecode(aws_ecs_task_definition.loop_runtime.container_definitions)[0].environment, { name = "BRAINSTORE_OTLP_TELEMETRY", value = "metrics,traces" }) &&
      jsondecode(aws_ecs_task_definition.loop_runtime.container_definitions)[0].logConfiguration.logDriver == "awsfirelens"
    )
    error_message = "With Pulse off, Loop must keep Datadog OTLP and FireLens logs."
  }
}

run "full_pulse_skips_datadog_agent_telemetry" {
  command = plan

  module {
    source = "./modules/loop-runtime-ecs"
  }

  assert {
    condition = (
      length([for env in jsondecode(aws_ecs_task_definition.loop_runtime.container_definitions)[0].environment : env if startswith(env.name, "BRAINSTORE_OTLP_")]) == 0 &&
      jsondecode(aws_ecs_task_definition.loop_runtime.container_definitions)[0].logConfiguration.logDriver == "awslogs" &&
      [for container in jsondecode(aws_ecs_task_definition.loop_runtime.container_definitions) : container.name] == ["loop-runtime", "datadog-agent"]
    )
    error_message = "With full Pulse, Loop must skip Datadog OTLP and FireLens but keep the Datadog agent."
  }
}

run "partial_pulse_skips_only_overlapping_signals" {
  command = plan

  module {
    source = "./modules/loop-runtime-ecs"
  }

  variables {
    extra_env_vars = { BRAINSTORE_CONTROL_PLANE_TELEMETRY = "status,metrics" }
  }

  assert {
    condition = (
      contains(jsondecode(aws_ecs_task_definition.loop_runtime.container_definitions)[0].environment, { name = "BRAINSTORE_OTLP_TELEMETRY", value = "traces" }) &&
      jsondecode(aws_ecs_task_definition.loop_runtime.container_definitions)[0].logConfiguration.logDriver == "awsfirelens"
    )
    error_message = "When Pulse carries only metrics, Loop must send traces to Datadog and keep FireLens logs."
  }
}
