output "otlp_env_vars" {
  description = "OTLP env vars that override the service environment. An empty endpoint disables OTLP."
  value = tomap(merge(
    { BRAINSTORE_OTLP_HTTP_ENDPOINT = length(local.datadog_agent_signals) == 0 ? "" : "http://localhost:4318" },
    local.datadog_agent_signals == local.otlp_signals || length(local.datadog_agent_signals) == 0 ? {} : {
      BRAINSTORE_OTLP_TELEMETRY = join(",", local.datadog_agent_signals)
    },
  ))
}

output "container_logs" {
  description = "Whether the Datadog agent ships container logs. False when Pulse sends logs."
  value       = !contains(local.pulse_signals, "logs")
}
