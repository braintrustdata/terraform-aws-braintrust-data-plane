variable "brainstore_license_key" {
  description = "The license key for the Brainstore instance. You can get this from the Braintrust UI in Settings > Data Plane."
  type        = string
  validation {
    condition     = var.brainstore_license_key != null && var.brainstore_license_key != ""
    error_message = "The brainstore_license_key must be set."
  }
}

variable "enable_observability" {
  description = "Whether to create the sandbox Grafana/Loki/Prometheus/Tempo/OpenTelemetry EC2 host and wire Brainstore OTLP telemetry to it."
  type        = bool
  default     = true
}
