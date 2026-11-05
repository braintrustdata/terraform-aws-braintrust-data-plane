variable "brainstore_license_key" {
  description = "License value for a module-managed secret. A supplied secret object takes precedence."
  type        = string
  default     = null
  sensitive   = true
}

variable "existing_brainstore_license_key_secret" {
  description = "Existing license secret and optional KMS key."
  type = object({
    arn         = string
    kms_key_arn = optional(string)
  })
  default = null
}
