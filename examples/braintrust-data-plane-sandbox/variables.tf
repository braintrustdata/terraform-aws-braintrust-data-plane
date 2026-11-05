variable "brainstore_license_key" {
  description = "License value for a module-managed secret. An existing secret ARN takes precedence."
  type        = string
  default     = null
  sensitive   = true
}

variable "brainstore_license_key_secret_arn" {
  description = "Existing Secrets Manager secret ARN for the plain license string."
  type        = string
  default     = null
}

variable "brainstore_license_key_kms_key_arn" {
  description = "Customer-managed KMS key ARN for the existing license secret."
  type        = string
  default     = null
}
