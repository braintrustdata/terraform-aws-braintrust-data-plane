# Pulse (BRAINSTORE_CONTROL_PLANE_TELEMETRY) already sends its signals to
# Datadog, so the agent skips them. A caller-set OTLP endpoint or signal list
# keeps the existing export.
locals {
  pulse_signals = var.enabled ? [
    for signal in split(",", lower(lookup(var.env_vars, "BRAINSTORE_CONTROL_PLANE_TELEMETRY", var.control_plane_telemetry))) : trimspace(signal)
  ] : []
  caller_sets_otlp = contains(keys(var.env_vars), "BRAINSTORE_OTLP_HTTP_ENDPOINT") || contains(keys(var.env_vars), "BRAINSTORE_OTLP_TELEMETRY")
}
