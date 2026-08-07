variable "deployment_name" {
  type        = string
  description = "Name of this deployment. Will be included in resource names."
}

variable "vpc_id" {
  type        = string
  description = "VPC ID where the API ECS ALB is deployed."
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Private subnet IDs for the API ECS ALB."
}

variable "authorized_security_groups" {
  type        = map(string)
  description = "Map of security group names to IDs authorized to access the API ECS ALB."
  default     = {}
}

variable "authorized_cidr_blocks" {
  type        = list(string)
  description = "CIDR blocks authorized to access the API ECS ALB."
  default     = []

  validation {
    condition     = alltrue([for cidr in var.authorized_cidr_blocks : can(cidrnetmask(cidr))])
    error_message = "authorized_cidr_blocks must contain valid CIDR blocks."
  }
}

variable "alb_certificate_arn" {
  type        = string
  description = "Optional ACM certificate ARN for the API ECS ALB. When set together with alb_custom_domain, the ALB serves HTTPS on port 443 instead of plain HTTP on port 80."
  default     = null
}

variable "alb_custom_domain" {
  type        = string
  description = "Optional custom domain served by the API ECS ALB. Must be covered by alb_certificate_arn. When set together with alb_certificate_arn, the ALB serves HTTPS on port 443 and the API URL becomes https://<alb_custom_domain>."
  default     = null

  validation {
    condition     = (var.alb_custom_domain == null) == (var.alb_certificate_arn == null)
    error_message = "alb_custom_domain and alb_certificate_arn must both be set or both be null."
  }
}

variable "alb_drop_invalid_header_fields" {
  type        = bool
  description = "Whether the API ECS ALB removes HTTP headers with invalid header names before routing requests."
  default     = false
}

variable "target_group_deregistration_delay_seconds" {
  type        = number
  description = "Seconds for the API ECS target group to wait before deregistering draining targets."
  default     = 300

  validation {
    condition     = var.target_group_deregistration_delay_seconds >= 0 && var.target_group_deregistration_delay_seconds <= 3600
    error_message = "target_group_deregistration_delay_seconds must be between 0 and 3600."
  }
}

variable "task_security_group_id" {
  type        = string
  description = "Security group ID attached to API ECS tasks (used for ALB→task ingress)."
}

variable "custom_tags" {
  description = "Custom tags to apply to all created resources."
  type        = map(string)
  default     = {}
}
