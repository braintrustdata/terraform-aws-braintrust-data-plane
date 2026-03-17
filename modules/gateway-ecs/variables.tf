variable "deployment_name" {
  type        = string
  description = "Name of this deployment. Will be included in resource names."
}

variable "kms_key_arn" {
  type        = string
  description = "KMS key ARN used to encrypt gateway resources that support customer-managed KMS keys."
}

variable "vpc_id" {
  type        = string
  description = "VPC ID where ECS resources are deployed."
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Private subnet IDs for ECS tasks and internal ALB."

  validation {
    condition     = length(var.private_subnet_ids) >= 2 && length(distinct(var.private_subnet_ids)) == length(var.private_subnet_ids)
    error_message = "private_subnet_ids must contain at least 2 unique subnet IDs."
  }
}

variable "ecs_cluster_arn" {
  type        = string
  description = "ARN of the ECS cluster where the gateway service will run."
}

variable "ecs_cluster_name" {
  type        = string
  description = "Name of the ECS cluster where the gateway service will run."
}

variable "container_image" {
  type        = string
  description = "Container image for the gateway ECS service."

  validation {
    condition     = trimspace(var.container_image) != ""
    error_message = "container_image must not be empty."
  }
}

variable "cpu" {
  type        = number
  description = "CPU units for the gateway task definition."
  default     = 2048
}

variable "memory" {
  type        = number
  description = "Memory (MiB) for the gateway task definition."
  default     = 4096
}

variable "min_capacity" {
  type        = number
  description = "Minimum number of gateway ECS tasks."
  default     = 2
}

variable "max_capacity" {
  type        = number
  description = "Maximum number of gateway ECS tasks."
  default     = 6

  validation {
    condition     = var.max_capacity >= var.min_capacity
    error_message = "max_capacity must be greater than or equal to min_capacity."
  }
}

variable "target_cpu_utilization" {
  type        = number
  description = "Target average CPU utilization percentage for gateway ECS service autoscaling."
  default     = 70

  validation {
    condition     = var.target_cpu_utilization > 0 && var.target_cpu_utilization <= 100
    error_message = "target_cpu_utilization must be between 1 and 100."
  }
}

variable "target_memory_utilization" {
  type        = number
  description = "Target average memory utilization percentage for gateway ECS service autoscaling."
  default     = 75

  validation {
    condition     = var.target_memory_utilization > 0 && var.target_memory_utilization <= 100
    error_message = "target_memory_utilization must be between 1 and 100."
  }
}

variable "log_retention_days" {
  type        = number
  description = "CloudWatch log retention days for gateway container logs."
  default     = 14

  validation {
    condition = contains([
      1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180,
      365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653
    ], var.log_retention_days)
    error_message = "log_retention_days must be a valid CloudWatch Logs retention value."
  }
}

variable "extra_env_vars" {
  type        = map(string)
  description = "Extra environment variables to inject into the gateway container."
  default     = {}

  validation {
    condition     = !contains(keys(var.extra_env_vars), "BRAINSTORE_LICENSE_KEY")
    error_message = "Do not set BRAINSTORE_LICENSE_KEY in extra_env_vars; use brainstore_license_key."
  }
}

variable "braintrust_app_url" {
  type        = string
  description = "Braintrust application URL used by the gateway."
  default     = "https://www.braintrust.dev"
}

variable "braintrust_api_url" {
  type        = string
  description = "Braintrust API URL used by the gateway."
  default     = "https://api.braintrust.dev"
}

variable "redis_host" {
  type        = string
  description = "Redis endpoint host used by the gateway auth cache."
}

variable "redis_port" {
  type        = number
  description = "Redis port used by the gateway auth cache."

  validation {
    condition     = var.redis_port >= 1 && var.redis_port <= 65535
    error_message = "redis_port must be between 1 and 65535."
  }
}

variable "redis_security_group_id" {
  type        = string
  description = "Security group ID of the dedicated gateway ElastiCache instance."
}

variable "authorized_security_groups" {
  type        = map(string)
  description = "Map of security group names to their IDs that are authorized to access the gateway ALB on port 80. Format: { name = <security_group_id> }"
  default     = {}
}

variable "custom_tags" {
  description = "Custom tags to apply to all created resources"
  type        = map(string)
  default     = {}
}

variable "brainstore_license_key" {
  type        = string
  description = "License key for the Brainstore instance. Used for telemetry authorization."
  default     = null
}

variable "cpu_architecture" {
  type        = string
  description = "CPU architecture for the gateway task definition."
  default     = "ARM64"

  validation {
    condition     = contains(["ARM64", "X86_64"], var.cpu_architecture)
    error_message = "cpu_architecture must be either ARM64 or X86_64."
  }
}

variable "enable_execute_command" {
  type        = bool
  description = "Enable ECS Exec on the gateway service."
  default     = false
}

