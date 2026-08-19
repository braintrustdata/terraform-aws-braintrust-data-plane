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

variable "kms_key_arn" {
  type        = string
  description = "KMS key ARN used to encrypt Redis URL secret."
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

variable "use_redis_replication_group" {
  description = "Use an ElastiCache replication group instead of the legacy single-node ElastiCache cluster. Existing deployments should leave this false until following the documented Redis migration procedure."
  type        = bool
}

variable "engine" {
  description = "ElastiCache engine to provision. Valkey is a Redis-compatible drop-in and uses the same redis:// / rediss:// URL schemes. Switching this on an existing deployment forces replacement of the cache cluster."
  type        = string
  default     = "redis"

  validation {
    condition     = contains(["redis", "valkey"], var.engine)
    error_message = "engine must be one of: redis, valkey."
  }
}

variable "redis_instance_type" {
  type        = string
  description = "Instance type for the Redis/Valkey cluster"
  default     = "cache.r7g.large"
}

variable "redis_version" {
  type        = string
  description = "Redis engine version. Used when engine = \"redis\"."
  default     = "7.0"
}

variable "valkey_engine_version" {
  type        = string
  description = "Valkey engine version. Used when engine = \"valkey\"."
  default     = "8.0"
}

variable "num_cache_clusters" {
  description = "Number of nodes in the replication group (primary + replicas). 1 = primary only; 2+ = active/passive with automatic failover. Only applies when use_redis_replication_group = true."
  type        = number
  default     = 1

  validation {
    condition     = var.num_cache_clusters >= 1 && var.num_cache_clusters <= 5
    error_message = "num_cache_clusters must be between 1 and 5."
  }
}

variable "custom_tags" {
  description = "Custom tags to apply to all created resources"
  type        = map(string)
  default     = {}
}
