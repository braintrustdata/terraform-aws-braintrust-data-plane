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
