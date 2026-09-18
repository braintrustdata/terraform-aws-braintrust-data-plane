variable "deployment_name" {
  type        = string
  description = "Name of this deployment. Will be included in resource names."
}

variable "vpc_id" {
  type        = string
  description = "VPC ID where the private API ALB is deployed."
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Private subnet IDs used by the API ALB."
}

variable "task_security_group_id" {
  type        = string
  description = "Security group ID attached to API ECS tasks."
}

variable "authorized_security_groups" {
  type        = map(string)
  description = "Map of security group names to IDs authorized to access the API ALB."
  default     = {}
}

variable "authorized_cidr_blocks" {
  type        = list(string)
  description = "CIDR blocks authorized to access the API ALB."
  default     = []

  validation {
    condition     = alltrue([for cidr in var.authorized_cidr_blocks : can(cidrnetmask(cidr))])
    error_message = "authorized_cidr_blocks must contain valid CIDR blocks."
  }
}

variable "certificate_arn" {
  type        = string
  description = "Optional ACM certificate ARN for HTTPS on the API ALB."
  default     = null
}

variable "custom_domain" {
  type        = string
  description = "Optional custom domain served by the API ALB. Must be covered by certificate_arn."
  default     = null

  validation {
    condition     = (var.custom_domain == null) == (var.certificate_arn == null)
    error_message = "custom_domain and certificate_arn must both be set or both be null."
  }
}

variable "drop_invalid_header_fields" {
  type        = bool
  description = "Whether the API ALB removes HTTP headers with invalid header names before routing requests."
  default     = false
}

variable "deregistration_delay" {
  type        = number
  description = "Seconds for API target groups to wait before deregistering draining targets."
  default     = 300

  validation {
    condition     = var.deregistration_delay >= 0 && var.deregistration_delay <= 3600
    error_message = "deregistration_delay must be between 0 and 3600."
  }
}

variable "custom_tags" {
  type        = map(string)
  description = "Custom tags to apply to created resources."
  default     = {}
}
