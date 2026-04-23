variable "deployment_name" {
  type        = string
  default     = "braintrust"
  description = "Name of this Braintrust deployment. Max 18 characters, lowercase letters, numbers, and hyphens only. Do not change after initial deployment."
}

variable "braintrust_org_name" {
  type        = string
  description = "Your organization name in Braintrust (e.g. acme.com)."
}

variable "brainstore_license_key" {
  type        = string
  sensitive   = true
  description = "Brainstore license key from the Braintrust UI under Settings > Data Plane."
  validation {
    condition     = var.brainstore_license_key != null && var.brainstore_license_key != ""
    error_message = "brainstore_license_key must be set."
  }
}

variable "helm_chart_version" {
  type        = string
  description = "Version of the Braintrust Helm chart (oci://public.ecr.aws/braintrust/helm) to deploy. Pin to a specific version for reproducible deployments."
}

variable "eks_namespace" {
  type        = string
  default     = "braintrust"
  description = "Kubernetes namespace for Braintrust workloads."
}

variable "brainstore_wal_footer_version" {
  type        = string
  default     = "v3"
  description = "WAL footer version for Brainstore. Only change when instructed by Braintrust."
}

variable "skip_pg_for_brainstore_objects" {
  type        = string
  default     = "all"
  description = "Controls which object types bypass PostgreSQL. WARNING: one-way operation."
}
