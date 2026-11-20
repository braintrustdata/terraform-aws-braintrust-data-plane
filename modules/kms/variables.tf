variable "deployment_name" {
  description = "Name of the deployment, used for resource naming"
  type        = string
}
variable "additional_key_policies" {
  description = "Additional IAM policy statements to append to the KMS key policy"
  type        = list(any)
  default     = []
}

variable "custom_tags" {
  description = "Custom tags to apply to all created resources"
  type        = map(string)
  default     = {}
}

variable "enable_kms_key_freeze" {
  type        = bool
  description = "Fail any plan whose configuration changes the managed KMS key or alias after this is turned on. Turn it on in an apply after the v8 upgrade, against a plan with no key or alias changes. To make an agreed key change, turn it off, apply the change, then turn it back on. See MIGRATION_V8.md."
  default     = false
}
