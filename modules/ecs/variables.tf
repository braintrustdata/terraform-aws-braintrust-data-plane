variable "deployment_name" {
  type        = string
  description = "Name of this deployment. Used in ECS cluster naming."
}

variable "enable_container_insights" {
  type        = bool
  description = "Whether to enable CloudWatch Container Insights for the ECS cluster."
  default     = true
}

variable "custom_tags" {
  description = "Custom tags to apply to all created resources"
  type        = map(string)
  default     = {}
}
