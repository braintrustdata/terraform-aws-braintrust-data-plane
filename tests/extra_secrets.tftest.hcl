# ARN-only ECS extra_secrets. Consumer secrets are valueFrom references.
# The license secret stays on its own input.

mock_provider "aws" {
  source = "./tests/mocks/aws"

  mock_data "aws_secretsmanager_secret_versions" {
    defaults = {
      versions = [
        { version_id = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee", version_stages = ["AWSCURRENT"] },
        { version_id = "ffffffff-bbbb-cccc-dddd-eeeeeeeeeeee", version_stages = ["AWSPREVIOUS"] },
      ]
    }
  }
}

mock_provider "random" {}

mock_provider "http" {
  source = "./tests/mocks/http"
}

run "api_ecs_extra_secret" {
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

    brainstore_license_key_secret_arn     = "arn:aws:secretsmanager:us-east-1:123456789012:secret:license"
    brainstore_license_key_secret_version = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
    extra_secrets = [
      {
        name      = "LAUNCHDARKLY_SDK_KEY"
        valueFrom = "arn:aws:secretsmanager:us-east-1:123456789012:secret:launchdarkly-XyZ123:::01234567-89ab-cdef-0123-456789abcdef"
      }
    ]
  }

  assert {
    condition = alltrue([
      for task in [aws_ecs_task_definition.braintrust_api, aws_ecs_task_definition.braintrust_api_ingest, aws_ecs_task_definition.braintrust_api_background] :
      one([for c in jsondecode(task.container_definitions) : one([for secret in c.secrets : secret.valueFrom if secret.name == "LAUNCHDARKLY_SDK_KEY"]) if c.name == "api"]) == "arn:aws:secretsmanager:us-east-1:123456789012:secret:launchdarkly-XyZ123:::01234567-89ab-cdef-0123-456789abcdef" &&
      one([for c in jsondecode(task.container_definitions) : one([for secret in c.secrets : secret.valueFrom if secret.name == "BRAINSTORE_LICENSE_KEY"]) if c.name == "api"]) == "arn:aws:secretsmanager:us-east-1:123456789012:secret:license:::aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
    ])
    error_message = "API extra secrets must be injected beside the license secret."
  }

  assert {
    condition     = strcontains(aws_iam_role_policy.task_execution_secrets.policy, "arn:aws:secretsmanager:us-east-1:123456789012:secret:launchdarkly-XyZ123") && !strcontains(aws_iam_role_policy.task_execution_secrets.policy, "01234567-89ab-cdef-0123-456789abcdef")
    error_message = "API execution IAM must allow the secret ARN without the version suffix."
  }
}

run "gateway_ecs_extra_secret" {
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
    gateway_url                               = "http://gateway.internal"
    redis_url_secret_arn                      = "arn:aws:secretsmanager:us-east-1:123456789012:secret:redis"
    redis_url_secret_version_id               = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
    redis_port                                = 6379
    redis_security_group_id                   = "sg-0123456789abcdef1"
    internal_observability_enabled            = true
    internal_observability_api_key_secret_arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:datadog"
    internal_observability_env_name           = "test"
    brainstore_license_key_secret_arn         = "arn:aws:secretsmanager:us-east-1:123456789012:secret:license"
    brainstore_license_key_secret_version     = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
    extra_env_vars = {
      NATIVE_INFERENCE_ENVIRONMENT = "eu"
    }
    extra_secrets = [
      {
        name      = "NATIVE_INFERENCE_SECRET_KEY"
        valueFrom = "arn:aws:secretsmanager:us-east-1:123456789012:secret:native-inference-AbCdEf"
      }
    ]
  }

  assert {
    condition     = one([for c in jsondecode(aws_ecs_task_definition.gateway.container_definitions) : one([for secret in c.secrets : secret.valueFrom if secret.name == "NATIVE_INFERENCE_SECRET_KEY"]) if c.name == "gateway"]) == "arn:aws:secretsmanager:us-east-1:123456789012:secret:native-inference-AbCdEf" && one([for c in jsondecode(aws_ecs_task_definition.gateway.container_definitions) : one([for secret in c.secrets : secret.valueFrom if secret.name == "BRAINSTORE_LICENSE_KEY"]) if c.name == "gateway"]) == "arn:aws:secretsmanager:us-east-1:123456789012:secret:license:::aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
    error_message = "Gateway extra secrets must be injected beside the license secret."
  }

  assert {
    condition     = strcontains(aws_iam_role_policy.task_execution_secrets.policy, "arn:aws:secretsmanager:us-east-1:123456789012:secret:native-inference-AbCdEf")
    error_message = "Gateway execution IAM must allow the consumer secret."
  }
}

run "root_wires_extra_secrets" {
  command = plan

  variables {
    deployment_name        = "bt-test"
    braintrust_org_name    = "test-org"
    primary_org_name       = "test-org"
    brainstore_license_key = "test-license"
    ai_gateway_extra_secrets = [
      {
        name      = "NATIVE_INFERENCE_SECRET_KEY"
        valueFrom = "arn:aws:secretsmanager:us-east-1:123456789012:secret:native-inference-AbCdEf"
      }
    ]
    braintrust_api_extra_secrets = [
      {
        name      = "LAUNCHDARKLY_SDK_KEY"
        valueFrom = "arn:aws:secretsmanager:us-east-1:123456789012:secret:launchdarkly-XyZ123:::01234567-89ab-cdef-0123-456789abcdef"
      }
    ]
  }
}

run "extra_env_denylist_rejects_secret_key" {
  command = plan

  variables {
    deployment_name        = "bt-test"
    braintrust_org_name    = "test-org"
    primary_org_name       = "test-org"
    brainstore_license_key = "test-license"
    ai_gateway_extra_env_vars = {
      NATIVE_INFERENCE_SECRET_KEY = "should-fail-validation"
    }
  }

  expect_failures = [
    var.ai_gateway_extra_env_vars,
  ]
}

run "extra_secrets_rejects_owned_name" {
  command = plan

  variables {
    deployment_name        = "bt-test"
    braintrust_org_name    = "test-org"
    primary_org_name       = "test-org"
    brainstore_license_key = "test-license"
    braintrust_api_extra_secrets = [
      {
        name      = "PG_URL"
        valueFrom = "arn:aws:secretsmanager:us-east-1:123456789012:secret:database-AbCdEf"
      }
    ]
  }

  expect_failures = [
    var.braintrust_api_extra_secrets,
  ]
}

run "extra_secrets_rejects_non_arn" {
  command = plan

  variables {
    deployment_name        = "bt-test"
    braintrust_org_name    = "test-org"
    primary_org_name       = "test-org"
    brainstore_license_key = "test-license"
    ai_gateway_extra_secrets = [
      {
        name      = "NATIVE_INFERENCE_SECRET_KEY"
        valueFrom = "not-an-arn"
      }
    ]
  }

  expect_failures = [
    var.ai_gateway_extra_secrets,
  ]
}
