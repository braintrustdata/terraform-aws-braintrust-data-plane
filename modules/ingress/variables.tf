variable "deployment_name" {
  type        = string
  description = "Name of this deployment. Will be included in resource names"
}

variable "custom_domain" {
  description = "Custom domain name for the CloudFront distribution"
  type        = string
  default     = null
}

variable "custom_certificate_arn" {
  description = "ARN of the ACM certificate for the custom domain"
  type        = string
  default     = null
}

variable "use_global_ai_proxy" {
  description = "Whether to use the global Cloudflare proxy"
  type        = bool
  default     = false
}

variable "ai_proxy_function_url" {
  description = "The function URL of the AI proxy lambda function"
  type        = string
}

variable "api_handler_function_arn" {
  description = "The ARN of the API handler lambda function"
  type        = string
}

variable "custom_tags" {
  description = "Custom tags to apply to all created resources"
  type        = map(string)
  default     = {}
}
