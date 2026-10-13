output "otlp_env_vars" {
  description = "OTLP env vars for the Datadog agent. They must override caller env vars. An empty endpoint disables OTLP when Pulse sends every signal."
  value = tomap(merge(
    { BRAINSTORE_OTLP_HTTP_ENDPOINT = length(local.datadog_agent_signals) == 0 ? "" : "http://localhost:4318" },
    length(local.datadog_agent_signals) == 0 || local.datadog_agent_signals == local.brainstore_signals ? {} : {
      BRAINSTORE_OTLP_TELEMETRY = join(",", local.datadog_agent_signals)
    },
  ))
}

output "container_logs" {
  description = "Whether the Datadog agent ships container logs, which Pulse replaces when it sends logs."
  value       = !contains(local.pulse_signals, "logs")
}
