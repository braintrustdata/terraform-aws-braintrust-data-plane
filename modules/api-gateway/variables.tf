variable "deployment_name" {
  type        = string
  description = "Name of this deployment. Included in API Gateway resource names."
}

variable "api_handler_function_name" {
  type        = string
  description = "Name of the API handler Lambda function."
}

variable "custom_tags" {
  type        = map(string)
  description = "Tags to apply to API Gateway resources."
  default     = {}
}
