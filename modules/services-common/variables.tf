variable "deployment_name" {
  type        = string
  description = "The name of the deployment"
}

variable "vpc_id" {
  type        = string
  description = "The ID of the VPC where Brainstore resources will be created"
}

variable "kms_key_arn" {
  type        = string
  description = "The ARN of the KMS key that encrypts the function tools secret."
}

variable "custom_tags" {
  description = "Custom tags to apply to all created resources"
  type        = map(string)
  default     = {}
}

variable "enable_quarantine_vpc" {
  type        = bool
  description = "Whether to create the quarantine Lambda security group. It is needed for running user-defined functions in an isolated environment."
  default     = false
}

variable "quarantine_vpc_id" {
  type        = string
  description = "The ID of the quarantine VPC. Required when enable_quarantine_vpc is true."
  default     = null
  validation {
    condition     = var.enable_quarantine_vpc ? var.quarantine_vpc_id != null : true
    error_message = "quarantine_vpc_id is required when enable_quarantine_vpc is true."
  }
}
