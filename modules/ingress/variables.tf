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

variable "use_api_ecs_for_eval_routes" {
  description = "Whether to route the CloudFormation-compatible eval/sandbox paths to API ECS."
  type        = bool
  default     = false
}

variable "api_ecs_origin_domain_name" {
  description = "Domain name for the API ECS ALB origin."
  type        = string
  default     = null

  validation {
    condition     = !var.use_api_ecs_for_eval_routes || var.api_ecs_origin_domain_name != null
    error_message = "api_ecs_origin_domain_name is required when use_api_ecs_for_eval_routes is true."
  }
}

variable "api_ecs_origin_arn" {
  description = "ARN for the API ECS ALB origin."
  type        = string
  default     = null

  validation {
    condition     = !var.use_api_ecs_for_eval_routes || var.api_ecs_origin_arn != null
    error_message = "api_ecs_origin_arn is required when use_api_ecs_for_eval_routes is true."
  }
}

variable "api_ecs_origin_protocol_policy" {
  description = "CloudFront origin protocol policy for API ECS origin."
  type        = string
  default     = null

  validation {
    condition = var.api_ecs_origin_protocol_policy == null ? true : contains([
      "http-only",
      "https-only",
      "match-viewer",
    ], var.api_ecs_origin_protocol_policy)
    error_message = "api_ecs_origin_protocol_policy must be http-only, https-only, or match-viewer."
  }

  validation {
    condition     = !var.use_api_ecs_for_eval_routes || var.api_ecs_origin_protocol_policy != null
    error_message = "api_ecs_origin_protocol_policy is required when use_api_ecs_for_eval_routes is true."
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
