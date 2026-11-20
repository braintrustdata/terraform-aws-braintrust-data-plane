variable "env_vars" {
  type        = map(string)
  description = "Service environment, including BRAINSTORE_CONTROL_PLANE_TELEMETRY (Pulse). Empty when the internal Datadog agent is off."
}
