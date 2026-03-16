variable "deployment_name" {
  type        = string
  description = "Name of this deployment. Used in ECS cluster naming."
}

variable "kms_key_arn" {
  type        = string
  description = "KMS key ARN used for ECS Exec and Fargate managed storage encryption."
}

variable "container_insights" {
  type        = string
  description = "CloudWatch Container Insights setting for the ECS cluster. Valid values: enabled, disabled, enhanced."
  default     = "enabled"

  validation {
    condition     = contains(["enabled", "disabled", "enhanced"], var.container_insights)
    error_message = "container_insights must be one of: enabled, disabled, enhanced."
  }
}

variable "custom_tags" {
  description = "Custom tags to apply to all created resources"
  type        = map(string)
  default     = {}
}
