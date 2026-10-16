# The Datadog agent gets every Brainstore OTLP signal that Pulse does not send.
locals {
  pulse_signals         = [for signal in split(",", lower(lookup(var.env_vars, "BRAINSTORE_CONTROL_PLANE_TELEMETRY", ""))) : trimspace(signal)]
  otlp_signals          = [for signal in split(",", lower(lookup(var.env_vars, "BRAINSTORE_OTLP_TELEMETRY", "metrics,logs,traces"))) : trimspace(signal)]
  datadog_agent_signals = [for signal in local.otlp_signals : signal if !contains(local.pulse_signals, signal)]
}
