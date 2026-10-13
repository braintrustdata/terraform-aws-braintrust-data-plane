# Pulse (BRAINSTORE_CONTROL_PLANE_TELEMETRY) already sends its signals to
# Datadog, so the agent gets every other OTLP signal and nothing twice.
locals {
  pulse_signals = var.enabled ? [
    for signal in split(",", lower(lookup(var.env_vars, "BRAINSTORE_CONTROL_PLANE_TELEMETRY", var.control_plane_telemetry))) : trimspace(signal)
  ] : []
  otlp_signals = [
    for signal in split(",", lower(lookup(var.env_vars, "BRAINSTORE_OTLP_TELEMETRY", var.otlp_telemetry))) : trimspace(signal)
  ]
  datadog_agent_signals = [for signal in local.otlp_signals : signal if !contains(local.pulse_signals, signal)]
  # Brainstore's built-in default, so an unchanged list stays implicit.
  brainstore_signals = [
    for signal in split(",", lower(lookup(var.env_vars, "BRAINSTORE_OTLP_TELEMETRY", "metrics,logs,traces"))) : trimspace(signal)
  ]
}
