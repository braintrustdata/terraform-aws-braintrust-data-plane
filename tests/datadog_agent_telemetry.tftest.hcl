run "pulse_off_keeps_datadog_agent_telemetry" {
  command = plan

  module {
    source = "./modules/datadog-agent-telemetry"
  }

  variables {
    env_vars = { BRAINSTORE_CONTROL_PLANE_TELEMETRY = "" }
  }

  assert {
    condition     = output.otlp_env_vars == tomap({ BRAINSTORE_OTLP_HTTP_ENDPOINT = "http://localhost:4318" }) && output.container_logs
    error_message = "With Pulse off, the Datadog agent must keep every signal."
  }
}

run "full_pulse_disables_datadog_agent_telemetry" {
  command = plan

  module {
    source = "./modules/datadog-agent-telemetry"
  }

  variables {
    env_vars = { BRAINSTORE_CONTROL_PLANE_TELEMETRY = "status,metrics,logs,traces", BRAINSTORE_OTLP_TELEMETRY = "metrics" }
  }

  assert {
    condition     = output.otlp_env_vars == tomap({ BRAINSTORE_OTLP_HTTP_ENDPOINT = "" }) && !output.container_logs
    error_message = "With full Pulse, the Datadog agent must get no OTLP signals or container logs."
  }
}

run "partial_pulse_skips_only_pulse_signals" {
  command = plan

  module {
    source = "./modules/datadog-agent-telemetry"
  }

  variables {
    env_vars = { BRAINSTORE_CONTROL_PLANE_TELEMETRY = "status, Metrics" }
  }

  assert {
    condition     = output.otlp_env_vars == tomap({ BRAINSTORE_OTLP_HTTP_ENDPOINT = "http://localhost:4318", BRAINSTORE_OTLP_TELEMETRY = "logs,traces" }) && output.container_logs
    error_message = "With partial Pulse, the Datadog agent must get only the signals Pulse does not send."
  }
}
