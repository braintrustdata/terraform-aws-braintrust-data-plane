variable "deployment_name" {
  type        = string
  description = "Name of this Braintrust deployment. Used for resource naming and tagging. Max 18 characters, lowercase letters, numbers, and hyphens only. Do not change after initial deployment."
  default     = "braintrust"
}

variable "braintrust_org_name" {
  type        = string
  description = "Your organization name in Braintrust (e.g. acme.com)."
}

variable "brainstore_license_key" {
  type        = string
  description = "Brainstore license key from the Braintrust UI under Settings > Data Plane."
  sensitive   = true
  validation {
    condition     = var.brainstore_license_key != null && var.brainstore_license_key != ""
    error_message = "brainstore_license_key must be set."
  }
}

variable "helm_chart_version" {
  type        = string
  description = "Version of the Braintrust Helm chart to deploy. Pin to a specific version for reproducible deployments."
}

variable "eks_namespace" {
  type        = string
  description = "Kubernetes namespace for Braintrust workloads."
  default     = "braintrust"
}

variable "brainstore_wal_footer_version" {
  type        = string
  description = "WAL footer version for Brainstore. Only change when instructed by Braintrust."
  default     = "v3"
}

variable "skip_pg_for_brainstore_objects" {
  type        = string
  description = "Controls which object types bypass PostgreSQL. WARNING: one-way operation."
  default     = "all"
}
