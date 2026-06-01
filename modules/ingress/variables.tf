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

variable "waf_acl_id" {
  description = "Optional WAF Web ACL ID to associate with the CloudFront distribution"
  type        = string
  default     = null
}

variable "use_global_ai_proxy" {
  description = "Whether to use the global Cloudflare proxy"
  type        = bool
  default     = false
}

variable "use_global_gateway_origin" {
  description = "Whether to route /v1/proxy traffic to gateway.braintrust.dev"
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

variable "cloudfront_price_class" {
  description = "The price class for the CloudFront distribution"
  type        = string
  default     = "PriceClass_100"
}

variable "cloudfront_origin_read_timeout" {
  description = "The read timeout (in seconds) for CloudFront origins. AWS CloudFront supports up to 180s; values above 60s may require an AWS Support ticket to raise the quota."
  type        = number
  default     = 60

  validation {
    condition     = var.cloudfront_origin_read_timeout >= 1 && var.cloudfront_origin_read_timeout <= 180
    error_message = "cloudfront_origin_read_timeout must be between 1 and 180 seconds."
  }
}

variable "custom_tags" {
  description = "Custom tags to apply to all created resources"
  type        = map(string)
  default     = {}
}
