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

variable "use_global_ai_gateway_origin" {
  description = "Whether to route /v1/proxy traffic to gateway.braintrust.dev"
  type        = bool
  default     = false
}

variable "global_ai_gateway_origin_domain" {
  description = "Gateway origin domain to use when use_global_ai_gateway_origin is enabled"
  type        = string
  default     = "gateway.braintrust.dev"
}

variable "ai_proxy_function_url" {
  description = "The function URL of the AI proxy lambda function"
  type        = string
}

variable "api_handler_function_arn" {
  description = "The ARN of the API handler lambda function"
  type        = string
}

variable "enable_full_ecs_api" {
  description = "Route CloudFront API and AI Proxy traffic to the API ECS ALB instead of API Gateway and the AI Proxy Lambda."
  type        = bool
  default     = false

  validation {
    condition     = !var.enable_full_ecs_api || (var.api_ecs_alb_arn != null && var.api_ecs_alb_domain != null)
    error_message = "enable_full_ecs_api requires api_ecs_alb_arn and api_ecs_alb_domain."
  }
}

variable "api_ecs_alb_arn" {
  description = "ARN of the API ECS ALB. When set, CloudFront creates a VPC origin for it; enable_full_ecs_api controls whether traffic is routed there."
  type        = string
  default     = null
}

variable "api_ecs_alb_domain" {
  description = "Domain used as the API ECS ALB CloudFront origin. When the ALB serves HTTPS this must be the custom domain covered by the ALB certificate so it validates; otherwise it is the ALB's AWS-assigned DNS name. Required when api_ecs_alb_arn is set."
  type        = string
  default     = null
}

variable "api_ecs_alb_https_enabled" {
  description = "Whether the API ECS ALB serves HTTPS. When true, CloudFront connects to the ALB origin over HTTPS; otherwise it connects over HTTP."
  type        = bool
  default     = false
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
