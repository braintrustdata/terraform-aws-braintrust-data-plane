# Render every ECS task definition directly so its container JSON is known and
# verify the application container, but not its observability sidecars, can
# open up to one million files.

mock_provider "aws" {
  source = "./tests/mocks/aws"
}

run "api_ecs_containers_have_one_million_nofile_limit" {
  command = plan

  module {
    source = "./modules/api-ecs"
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

  assert {
    condition = alltrue([
      for task_definition in [
        aws_ecs_task_definition.braintrust_api,
        aws_ecs_task_definition.braintrust_api_ingest,
        aws_ecs_task_definition.braintrust_api_background,
        ] : one([
          for container in jsondecode(task_definition.container_definitions) : container
          if container.name == "api"
      ]).ulimits == [{ name = "nofile", softLimit = 1048576, hardLimit = 1048576 }]
    ])
    error_message = "Every API ECS application container must have a nofile soft and hard limit of 1048576."
  }
}

run "gateway_containers_have_one_million_nofile_limit" {
  command = plan

  module {
    source = "./modules/gateway-ecs"
  }

  variables {
    deployment_name                           = "bt-test"
    kms_key_arn                               = "arn:aws:kms:us-east-1:123456789012:key/test"
    vpc_id                                    = "vpc-0123456789abcdef0"
    private_subnet_ids                        = ["subnet-0123456789abcdef0", "subnet-0123456789abcdef1"]
    ecs_cluster_arn                           = "arn:aws:ecs:us-east-1:123456789012:cluster/bt-test"
    ecs_cluster_name                          = "bt-test"
    container_image                           = "123456789012.dkr.ecr.us-east-1.amazonaws.com/gateway:test"
    target_group_arn                          = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/gateway/1234567890123456"
    alb_security_group_id                     = "sg-0123456789abcdef2"
    gateway_http_listener_arn                 = "arn:aws:elasticloadbalancing:us-east-1:123456789012:listener/app/gateway/1234567890123456/1234567890123456"
    use_redis_replication_group               = false
    redis_host                                = "redis.example.internal"
    redis_port                                = 6379
    redis_security_group_id                   = "sg-0123456789abcdef1"
    internal_observability_enabled            = true
    internal_observability_api_key_secret_arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:datadog"
    internal_observability_env_name           = "test"
  }

  assert {
    condition = (
      one([
        for container in jsondecode(aws_ecs_task_definition.gateway.container_definitions) : container
        if container.name == "gateway"
      ]).ulimits == [{ name = "nofile", softLimit = 1048576, hardLimit = 1048576 }]
      && alltrue([
        for container in jsondecode(aws_ecs_task_definition.gateway.container_definitions) :
        container.name == "gateway" || !contains(keys(container), "ulimits")
      ])
    )
    error_message = "Only the Gateway ECS application container must have a nofile soft and hard limit of 1048576."
  }
}

run "loop_runtime_containers_have_one_million_nofile_limit" {
  command = plan

  module {
    source = "./modules/loop-runtime-ecs"
  }

  variables {
    deployment_name                           = "bt-test"
    kms_key_arn                               = "arn:aws:kms:us-east-1:123456789012:key/test"
    vpc_id                                    = "vpc-0123456789abcdef0"
    private_subnet_ids                        = ["subnet-0123456789abcdef0", "subnet-0123456789abcdef1"]
    ecs_cluster_arn                           = "arn:aws:ecs:us-east-1:123456789012:cluster/bt-test"
    ecs_cluster_name                          = "bt-test"
    container_image                           = "123456789012.dkr.ecr.us-east-1.amazonaws.com/loop-runtime:test"
    target_group_arn                          = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/loop-runtime/1234567890123456"
    alb_security_group_id                     = "sg-0123456789abcdef2"
    loop_runtime_http_listener_arn            = "arn:aws:elasticloadbalancing:us-east-1:123456789012:listener/app/loop-runtime/1234567890123456/1234567890123456"
    database_url_secret_arn                   = "arn:aws:secretsmanager:us-east-1:123456789012:secret:database"
    redis_url_secret_arn                      = "arn:aws:secretsmanager:us-east-1:123456789012:secret:redis"
    function_tools_secret_arn                 = "arn:aws:secretsmanager:us-east-1:123456789012:secret:function-tools"
    brainstore_s3_bucket_name                 = "bt-test-brainstore"
    brainstore_s3_bucket_arn                  = "arn:aws:s3:::bt-test-brainstore"
    code_bundle_bucket                        = "bt-test-code"
    code_bundle_bucket_arn                    = "arn:aws:s3:::bt-test-code"
    brainstore_reader_url                     = "http://brainstore.example.internal:9000"
    ai_proxy_url                              = "https://api.example.com/v1/proxy"
    braintrust_api_url                        = "https://api.example.com"
    internal_observability_enabled            = true
    internal_observability_api_key_secret_arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:datadog"
    internal_observability_env_name           = "test"
  }

  assert {
    condition = (
      one([
        for container in jsondecode(aws_ecs_task_definition.loop_runtime.container_definitions) : container
        if container.name == "loop-runtime"
      ]).ulimits == [{ name = "nofile", softLimit = 1048576, hardLimit = 1048576 }]
      && alltrue([
        for container in jsondecode(aws_ecs_task_definition.loop_runtime.container_definitions) :
        container.name == "loop-runtime" || !contains(keys(container), "ulimits")
      ])
    )
    error_message = "Only the Loop Runtime ECS application container must have a nofile soft and hard limit of 1048576."
  }
}
