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

variable "ai_proxy_function_url" {
  description = "The function URL of the AI proxy lambda function"
  type        = string
}

variable "api_ecs_origin_domain_name" {
  description = "Optional domain name for the API-ECS ALB origin"
  type        = string
  default     = null
}

variable "api_ecs_origin_arn" {
  description = "Optional ARN for the API-ECS ALB origin"
  type        = string
  default     = null
}

variable "api_ecs_origin_protocol_policy" {
  description = "CloudFront origin protocol policy for API-ECS origin."
  type        = string
  default     = null

  validation {
    condition = contains([
      "http-only",
      "https-only",
      "match-viewer",
    ], coalesce(var.api_ecs_origin_protocol_policy, "http-only"))
    error_message = "api_ecs_origin_protocol_policy must be null, http-only, https-only, or match-viewer."
  }
}

variable "has_api_ecs_origin" {
  description = "Whether API-ECS origin resources should be created in CloudFront."
  type        = bool
  default     = false
}

variable "use_api_ecs_for_eval_routes" {
  description = "Route /v1/eval* paths to API-ECS origin"
  type        = bool
  default     = false

  validation {
    condition     = !var.use_api_ecs_for_eval_routes || var.has_api_ecs_origin
    error_message = "use_api_ecs_for_eval_routes requires API-ECS origin to be enabled."
  }
}

variable "use_api_ecs_for_all_proxy_routes" {
  description = "Route all proxy-related paths to API-ECS origin"
  type        = bool
  default     = false

  validation {
    condition     = !var.use_api_ecs_for_all_proxy_routes || var.has_api_ecs_origin
    error_message = "use_api_ecs_for_all_proxy_routes requires API-ECS origin to be enabled."
  }
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

variable "custom_tags" {
  description = "Custom tags to apply to all created resources"
  type        = map(string)
  default     = {}
}
