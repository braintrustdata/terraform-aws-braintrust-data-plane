variable "enabled" {
  type        = bool
  description = "Whether the internal Datadog agent is deployed. When false, every signal is kept."
}

variable "env_vars" {
  type        = map(string)
  description = "Caller environment overrides for the service."
}

variable "control_plane_telemetry" {
  type        = string
  description = "BRAINSTORE_CONTROL_PLANE_TELEMETRY (Pulse) value used when env_vars does not set it."
}

variable "otlp_telemetry" {
  type        = string
  description = "OTLP signals the service sends to the Datadog agent when env_vars does not set BRAINSTORE_OTLP_TELEMETRY."
}
