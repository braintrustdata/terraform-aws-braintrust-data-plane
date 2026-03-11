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

variable "custom_security_group_ids" {
  type        = list(string)
  description = "Advanced: Use existing security group IDs instead of the one created by this module. When non-empty, this module will not create or manage the ElastiCache security group or its ingress/egress rules."
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
