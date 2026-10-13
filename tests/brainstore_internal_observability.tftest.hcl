# The internal Datadog agent skips the Brainstore telemetry that each role's
# effective BRAINSTORE_CONTROL_PLANE_TELEMETRY (Pulse) already carries.

mock_provider "aws" {
  source = "./tests/mocks/aws"
}

variables {
  deployment_name                       = "bt-internal-obs"
  license_key                           = "test-license"
  kms_key_arn                           = "arn:aws:kms:us-east-1:123456789012:key/00000000-0000-0000-0000-000000000000"
  vpc_id                                = "vpc-12345678"
  private_subnet_ids                    = ["subnet-12345678", "subnet-23456789", "subnet-34567890"]
  database_secret_arn                   = "arn:aws:secretsmanager:us-east-1:123456789012:secret:bt-internal-obs-database"
  database_host                         = "database.example.internal"
  database_port                         = "5432"
  use_redis_replication_group           = true
  redis_host                            = "redis.example.internal"
  redis_port                            = "6379"
  service_token_secret_arn              = "arn:aws:secretsmanager:us-east-1:123456789012:secret:bt-internal-obs-service-token"
  brainstore_s3_bucket_arn              = "arn:aws:s3:::bt-internal-obs-brainstore"
  lambda_responses_s3_bucket_arn        = "arn:aws:s3:::bt-internal-obs-lambda-responses"
  code_bundle_s3_bucket_arn             = "arn:aws:s3:::bt-internal-obs-code-bundles"
  brainstore_iam_role_name              = "bt-internal-obs-brainstore"
  brainstore_instance_security_group_id = "sg-12345678"
  ai_proxy_url_ssm_parameter            = "/bt-internal-obs/ai-proxy-url"
  fast_reader_instance_count            = 1
  automation_writer_instance_count      = 1
  internal_observability_api_key        = "test-datadog-key"
  monitoring_telemetry                  = "status,metrics,usage,memprof,traces,logs"
}

run "pulse_off_keeps_datadog_agent_path" {
  command = plan

  module {
    source = "./modules/brainstore-ec2"
  }

  variables {
    extra_env_vars                   = { BRAINSTORE_CONTROL_PLANE_TELEMETRY = "" }
    extra_env_vars_writer            = { BRAINSTORE_CONTROL_PLANE_TELEMETRY = "" }
    extra_env_vars_fast_reader       = { BRAINSTORE_CONTROL_PLANE_TELEMETRY = "none" }
    extra_env_vars_automation_writer = { BRAINSTORE_CONTROL_PLANE_TELEMETRY = "" }
  }

  assert {
    condition = alltrue([for role, env in local.datadog_agent_otlp_env_vars :
    env == tomap({ BRAINSTORE_OTLP_HTTP_ENDPOINT = "http://localhost:4318" }) && module.datadog_agent_telemetry[role].container_logs])
    error_message = "With Pulse off, every role must keep the existing Datadog OTLP endpoint and container logs."
  }
}

run "full_pulse_skips_datadog_agent_telemetry" {
  command = plan

  module {
    source = "./modules/brainstore-ec2"
  }

  assert {
    condition = alltrue([for role, env in local.datadog_agent_otlp_env_vars :
    length(env) == 0 && !module.datadog_agent_telemetry[role].container_logs])
    error_message = "With full Pulse, no role may send Brainstore OTLP or container logs to the Datadog agent."
  }
}

run "partial_pulse_and_explicit_overrides" {
  command = plan

  module {
    source = "./modules/brainstore-ec2"
  }

  variables {
    monitoring_telemetry             = "status,metrics"
    extra_env_vars_writer            = { BRAINSTORE_CONTROL_PLANE_TELEMETRY = "status,logs" }
    extra_env_vars_fast_reader       = { BRAINSTORE_OTLP_TELEMETRY = "metrics" }
    extra_env_vars_automation_writer = { BRAINSTORE_OTLP_HTTP_ENDPOINT = "http://collector.example.internal:4318" }
  }

  assert {
    condition = (
      local.datadog_agent_otlp_env_vars.reader == tomap({ BRAINSTORE_OTLP_HTTP_ENDPOINT = "http://localhost:4318", BRAINSTORE_OTLP_TELEMETRY = "logs,traces" }) &&
      local.datadog_agent_otlp_env_vars.writer == tomap({ BRAINSTORE_OTLP_HTTP_ENDPOINT = "http://localhost:4318", BRAINSTORE_OTLP_TELEMETRY = "metrics,traces" }) &&
      local.datadog_agent_otlp_env_vars.fast_reader == tomap({ BRAINSTORE_OTLP_HTTP_ENDPOINT = "http://localhost:4318" }) &&
      local.datadog_agent_otlp_env_vars.automation_writer == tomap({ BRAINSTORE_OTLP_HTTP_ENDPOINT = "http://localhost:4318" }) &&
      { for role, telemetry in module.datadog_agent_telemetry : role => telemetry.container_logs } == { reader = true, writer = false, fast_reader = true, automation_writer = true }
    )
    error_message = "Each role must skip only its own Pulse signals and keep explicit OTLP settings."
  }
}

run "customer_user_data_unchanged_without_internal_key" {
  command = plan

  module {
    source = "./modules/brainstore-ec2"
  }

  variables {
    internal_observability_api_key = ""
    extra_env_vars                 = { BRAINSTORE_OTLP_HTTP_ENDPOINT = "http://collector.example.internal:4318" }
  }

  assert {
    condition = alltrue([for role, env in local.datadog_agent_otlp_env_vars :
    env == tomap({ BRAINSTORE_OTLP_HTTP_ENDPOINT = "http://localhost:4318" }) && module.datadog_agent_telemetry[role].container_logs])
    error_message = "Without the internal key, rendered agent configuration must not change."
  }
}
