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
variable "diagnostics_transcript_log_group_name" {
  description = "Optional existing CloudWatch log group in this account and region for protected SSM and ECS Exec transcripts. The bootstrap owns the group. Null preserves existing logging and permissions; session enablement flags remain independent."
  type        = string
  default     = null

  validation {
    condition     = var.diagnostics_transcript_log_group_name == null ? true : can(regex("^[A-Za-z0-9_./#-]{1,512}$", var.diagnostics_transcript_log_group_name))
    error_message = "diagnostics_transcript_log_group_name must be a nonempty exact CloudWatch log group name, without wildcards."
  }
}
