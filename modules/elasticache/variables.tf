variable "deployment_name" {
  type        = string
  description = "Name of this deployment. Will be included in resource names"
}

variable "subnet_ids" {
  type        = list(string)
  description = "List of subnet IDs for the ElastiCache subnet group"
}

variable "vpc_id" {
  type        = string
  description = "ID of VPC where Elasticache will be deployed."
}

variable "authorized_security_groups" {
  type        = map(string)
  description = "Map of security group names to their IDs that are authorized to access Elasticache. Format: { name = <security_group_id> }"
  default     = {}
}

variable "attach_additional_security_groups" {
  type        = list(string)
  description = "Advanced: Optional list of additional security group IDs to directly attach to the ElastiCache cluster security groups. This is not usually required and should only be used for specialized networking configurations."
  default     = []
}

variable "redis_instance_type" {
  type        = string
  description = "Instance type for the Redis cluster"
  default     = "cache.t4g.medium"
}

variable "redis_version" {
  type        = string
  description = "Redis engine version"
  default     = "7.0"
}

variable "custom_tags" {
  description = "Custom tags to apply to all created resources"
  type        = map(string)
  default     = {}
}
