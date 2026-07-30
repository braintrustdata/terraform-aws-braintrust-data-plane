variable "deployment_name" {
  type        = string
  description = "Name of this deployment. Will be included in resource names."
}

variable "vpc_id" {
  type        = string
  description = "VPC ID where the private Loop runtime ALB is deployed."
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Private subnet IDs used when loop_runtime_alb_subnet_ids is empty."

  validation {
    condition     = length(var.private_subnet_ids) >= 2 && length(distinct(var.private_subnet_ids)) == length(var.private_subnet_ids)
    error_message = "private_subnet_ids must contain at least 2 unique subnet IDs."
  }
}

variable "loop_runtime_alb_subnet_ids" {
  type        = list(string)
  description = "Subnet IDs for the Loop runtime internal ALB. Defaults to private_subnet_ids when empty."
  default     = []

  validation {
    condition     = length(var.loop_runtime_alb_subnet_ids) == 0 || (length(var.loop_runtime_alb_subnet_ids) >= 2 && length(distinct(var.loop_runtime_alb_subnet_ids)) == length(var.loop_runtime_alb_subnet_ids))
    error_message = "loop_runtime_alb_subnet_ids must contain at least 2 unique subnet IDs when set."
  }
}

variable "authorized_security_groups" {
  type        = map(string)
  description = "Security groups authorized to reach the Loop runtime ALB on port 4001 (e.g. API, Brainstore, custom callers)."
  default     = {}
}

variable "enable_cloudfront_vpc_origin_ingress" {
  type        = bool
  description = "Allow inbound HTTP to the Loop runtime ALB from the CloudFront VPC origin managed prefix list."
  default     = false
}

variable "alb_client_keep_alive" {
  type        = number
  description = "Client keep-alive duration in seconds for the Loop runtime ALB."
  default     = 4000

  validation {
    condition     = var.alb_client_keep_alive >= 60 && var.alb_client_keep_alive <= 604800
    error_message = "alb_client_keep_alive must be between 60 and 604800 seconds."
  }
}

variable "alb_idle_timeout" {
  type        = number
  description = "Idle timeout in seconds for the Loop runtime ALB."
  default     = 3600

  validation {
    condition     = var.alb_idle_timeout >= 1 && var.alb_idle_timeout <= 4000
    error_message = "alb_idle_timeout must be between 1 and 4000 seconds."
  }
}

variable "alb_deregistration_delay" {
  type        = number
  description = "Seconds for the Loop runtime target group to wait before deregistering draining targets."
  default     = 900

  validation {
    condition     = var.alb_deregistration_delay >= 0 && var.alb_deregistration_delay <= 3600
    error_message = "alb_deregistration_delay must be between 0 and 3600 seconds."
  }
}

variable "alb_drop_invalid_header_fields" {
  type        = bool
  description = "Whether the Loop runtime ALB removes HTTP headers with invalid header names before routing requests."
  default     = false
}

variable "custom_tags" {
  type        = map(string)
  description = "Tags to apply to created resources."
  default     = {}
}
