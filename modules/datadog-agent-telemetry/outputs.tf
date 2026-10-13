output "otlp_telemetry" {
  description = "Signals to send to the Datadog agent over OTLP, or empty when Pulse sends them all."
  value = join(",", [
    for signal in split(",", var.otlp_telemetry) : signal
    if local.caller_sets_otlp || !contains(local.pulse_signals, signal)
  ])
}

output "container_logs" {
  description = "Whether the Datadog agent ships container logs, which Pulse replaces when it sends logs."
  value       = !contains(local.pulse_signals, "logs")
}
