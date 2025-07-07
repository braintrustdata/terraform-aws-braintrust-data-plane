variable "deployment_name" {
  type        = string
  description = "Name of this deployment. Will be included in resource names"
}

variable "subnet_ids" {
  type        = list(string)
  description = "List of subnet IDs for the ElastiCache subnet group"
}

variable "security_group_ids" {
  type        = list(string)
  description = "List of security group IDs for the ElastiCache cluster"
}

variable "redis_instance_type" {
  type        = string
  description = "Instance type for the Redis cluster"
  default     = "cache.m7g.large"
}

variable "redis_version" {
  type        = string
  description = "Redis engine version"
  default     = "7.0"
}
