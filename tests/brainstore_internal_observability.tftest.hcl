# Verify the internal Datadog agent skips the Brainstore telemetry that each
# role's effective Pulse setting (BRAINSTORE_CONTROL_PLANE_TELEMETRY) carries.

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
  writer_instance_count                 = 1
  fast_reader_instance_count            = 1
  automation_writer_instance_count      = 1
}

run "customer_deployments_keep_existing_agent_config" {
  command = plan

  module {
    source = "./modules/brainstore-ec2"
  }

  variables {
    monitoring_telemetry = "status,metrics,usage,memprof,traces,logs"
    extra_env_vars = {
      BRAINSTORE_OTLP_HTTP_ENDPOINT = "http://collector.example.internal:4318"
    }
  }

  assert {
    condition = alltrue([
      for role in ["reader", "writer", "fast_reader", "automation_writer"] :
      local.datadog_agent_otlp_env_vars[role] == tomap({ BRAINSTORE_OTLP_HTTP_ENDPOINT = "http://localhost:4318" }) &&
      local.datadog_agent_container_logs[role]
    ])
    error_message = "Without the internal Datadog key, rendered agent configuration must not change."
  }
}

run "pulse_disabled_keeps_datadog_agent_path" {
  command = plan

  module {
    source = "./modules/brainstore-ec2"
  }

  variables {
    internal_observability_api_key = "test-datadog-key"
    monitoring_telemetry           = ""
  }

  assert {
    condition = alltrue([
      for role in ["reader", "writer", "fast_reader", "automation_writer"] :
      local.datadog_agent_otlp_env_vars[role] == tomap({ BRAINSTORE_OTLP_HTTP_ENDPOINT = "http://localhost:4318" }) &&
      local.datadog_agent_container_logs[role]
    ])
    error_message = "With Pulse off, every role must keep the existing Datadog OTLP endpoint and container logs."
  }
}

run "explicit_empty_pulse_override_keeps_datadog_agent_path" {
  command = plan

  module {
    source = "./modules/brainstore-ec2"
  }

  variables {
    internal_observability_api_key   = "test-datadog-key"
    monitoring_telemetry             = "status,metrics,usage,memprof,traces,logs"
    extra_env_vars                   = { BRAINSTORE_CONTROL_PLANE_TELEMETRY = "" }
    extra_env_vars_writer            = { BRAINSTORE_CONTROL_PLANE_TELEMETRY = "" }
    extra_env_vars_fast_reader       = { BRAINSTORE_CONTROL_PLANE_TELEMETRY = "none" }
    extra_env_vars_automation_writer = { BRAINSTORE_CONTROL_PLANE_TELEMETRY = "" }
  }

  assert {
    condition = alltrue([
      for role in ["reader", "writer", "fast_reader", "automation_writer"] :
      local.datadog_agent_otlp_env_vars[role] == tomap({ BRAINSTORE_OTLP_HTTP_ENDPOINT = "http://localhost:4318" }) &&
      local.datadog_agent_container_logs[role]
    ])
    error_message = "An explicit empty Pulse override must keep the existing Datadog OTLP endpoint and container logs."
  }
}

run "full_pulse_skips_brainstore_telemetry_on_datadog_agent" {
  command = plan

  module {
    source = "./modules/brainstore-ec2"
  }

  variables {
    internal_observability_api_key = "test-datadog-key"
    monitoring_telemetry           = "status,metrics,usage,memprof,traces,logs"
  }

  assert {
    condition = alltrue([
      for role in ["reader", "writer", "fast_reader", "automation_writer"] :
      length(local.datadog_agent_otlp_env_vars[role]) == 0 && !local.datadog_agent_container_logs[role]
    ])
    error_message = "When Pulse carries metrics, logs, and traces, no role may send Brainstore OTLP or container logs to the Datadog agent."
  }
}

run "partial_pulse_skips_only_overlapping_signals" {
  command = plan

  module {
    source = "./modules/brainstore-ec2"
  }

  variables {
    internal_observability_api_key = "test-datadog-key"
    monitoring_telemetry           = "status,metrics,usage"
  }

  assert {
    condition = alltrue([
      for role in ["reader", "writer", "fast_reader", "automation_writer"] :
      local.datadog_agent_otlp_env_vars[role] == tomap({
        BRAINSTORE_OTLP_HTTP_ENDPOINT = "http://localhost:4318"
        BRAINSTORE_OTLP_TELEMETRY     = "logs,traces"
      }) &&
      local.datadog_agent_container_logs[role]
    ])
    error_message = "When Pulse carries only metrics, every role must send logs and traces to the Datadog agent."
  }
}

run "per_role_pulse_overrides_set_each_role" {
  command = plan

  module {
    source = "./modules/brainstore-ec2"
  }

  variables {
    internal_observability_api_key   = "test-datadog-key"
    monitoring_telemetry             = "status,metrics,usage,memprof,traces,logs"
    extra_env_vars                   = { BRAINSTORE_CONTROL_PLANE_TELEMETRY = "" }
    extra_env_vars_writer            = { BRAINSTORE_CONTROL_PLANE_TELEMETRY = "status,logs" }
    extra_env_vars_automation_writer = { BRAINSTORE_CONTROL_PLANE_TELEMETRY = "STATUS, Traces" }
  }

  assert {
    condition = (
      local.datadog_agent_otlp_env_vars.reader == tomap({ BRAINSTORE_OTLP_HTTP_ENDPOINT = "http://localhost:4318" }) &&
      local.datadog_agent_container_logs.reader
    )
    error_message = "The reader's empty Pulse override must keep the existing Datadog agent path."
  }

  assert {
    condition = (
      local.datadog_agent_otlp_env_vars.writer == tomap({
        BRAINSTORE_OTLP_HTTP_ENDPOINT = "http://localhost:4318"
        BRAINSTORE_OTLP_TELEMETRY     = "metrics,traces"
      }) &&
      !local.datadog_agent_container_logs.writer
    )
    error_message = "The writer's Pulse override carries logs, so the agent must skip Brainstore logs only."
  }

  assert {
    condition = (
      length(local.datadog_agent_otlp_env_vars.fast_reader) == 0 &&
      !local.datadog_agent_container_logs.fast_reader
    )
    error_message = "The fast reader inherits full Pulse telemetry, so the agent must skip its Brainstore telemetry."
  }

  assert {
    condition = (
      local.datadog_agent_otlp_env_vars.automation_writer == tomap({
        BRAINSTORE_OTLP_HTTP_ENDPOINT = "http://localhost:4318"
        BRAINSTORE_OTLP_TELEMETRY     = "metrics,logs"
      }) &&
      local.datadog_agent_container_logs.automation_writer
    )
    error_message = "The automation writer's Pulse override carries traces, so the agent must skip Brainstore traces only."
  }
}

run "explicit_otlp_overrides_are_kept" {
  command = plan

  module {
    source = "./modules/brainstore-ec2"
  }

  variables {
    internal_observability_api_key = "test-datadog-key"
    monitoring_telemetry           = "status,metrics,usage"
    extra_env_vars                 = { BRAINSTORE_OTLP_TELEMETRY = "metrics,traces" }
    extra_env_vars_writer          = { BRAINSTORE_OTLP_HTTP_ENDPOINT = "http://collector.example.internal:4318" }
    extra_env_vars_fast_reader     = { BRAINSTORE_OTLP_TELEMETRY = "metrics" }
  }

  assert {
    condition     = local.datadog_agent_otlp_env_vars.reader == tomap({ BRAINSTORE_OTLP_HTTP_ENDPOINT = "http://localhost:4318" })
    error_message = "An explicit BRAINSTORE_OTLP_TELEMETRY must not be overwritten."
  }

  assert {
    condition     = length(local.datadog_agent_otlp_env_vars.writer) == 0
    error_message = "An explicit BRAINSTORE_OTLP_HTTP_ENDPOINT must not be overwritten."
  }

  assert {
    condition     = length(local.datadog_agent_otlp_env_vars.fast_reader) == 0
    error_message = "When Pulse carries every explicitly selected OTLP signal, the agent endpoint must not be set."
  }

  assert {
    condition = local.datadog_agent_otlp_env_vars.automation_writer == tomap({
      BRAINSTORE_OTLP_HTTP_ENDPOINT = "http://localhost:4318"
      BRAINSTORE_OTLP_TELEMETRY     = "logs,traces"
    })
    error_message = "Roles without OTLP overrides must send only the signals Pulse does not carry."
  }
}

run "user_data_keeps_existing_datadog_agent_config" {
  command = apply

  module {
    source = "./tests/fixtures/brainstore-user-data"
  }

  variables {
    datadog_agent_container_logs = true
    datadog_agent_otlp_env_vars  = { BRAINSTORE_OTLP_HTTP_ENDPOINT = "http://localhost:4318" }
  }

  assert {
    condition = (
      strcontains(output.script, "cat <<EOF >> /etc/brainstore.env\nBRAINSTORE_OTLP_HTTP_ENDPOINT=http://localhost:4318\nEOF\nfi\n") &&
      strcontains(output.script, "container_collect_all: true")
    )
    error_message = "user_data must keep the existing Datadog OTLP endpoint and container log collection."
  }
}

run "user_data_limits_datadog_agent_signals" {
  command = apply

  module {
    source = "./tests/fixtures/brainstore-user-data"
  }

  variables {
    datadog_agent_container_logs = true
    datadog_agent_otlp_env_vars = {
      BRAINSTORE_OTLP_HTTP_ENDPOINT = "http://localhost:4318"
      BRAINSTORE_OTLP_TELEMETRY     = "logs,traces"
    }
  }

  assert {
    condition     = strcontains(output.script, "cat <<EOF >> /etc/brainstore.env\nBRAINSTORE_OTLP_HTTP_ENDPOINT=http://localhost:4318\nBRAINSTORE_OTLP_TELEMETRY=logs,traces\nEOF\nfi\n")
    error_message = "user_data must limit Brainstore OTLP to the signals Pulse does not carry."
  }
}

run "user_data_skips_brainstore_telemetry_on_datadog_agent" {
  command = apply

  module {
    source = "./tests/fixtures/brainstore-user-data"
  }

  variables {
    datadog_agent_container_logs = false
    datadog_agent_otlp_env_vars  = {}
  }

  assert {
    condition = (
      !strcontains(output.script, "BRAINSTORE_OTLP_HTTP_ENDPOINT") &&
      !strcontains(output.script, "container_collect_all") &&
      strcontains(output.script, "install_script_agent7.sh") &&
      strcontains(output.script, "collect_aws_ena_metrics: true") &&
      strcontains(output.script, "\"file_path\": \"/var/lib/docker/containers/*/*.log\"")
    )
    error_message = "The Datadog agent must keep host and network metrics, and CloudWatch must keep container logs."
  }
}
