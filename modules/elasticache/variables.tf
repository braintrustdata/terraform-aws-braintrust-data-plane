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
  description = "KMS key ARN used to encrypt the Redis-compatible Redis/Valkey URL secret."
}

variable "authorized_security_groups" {
  type        = map(string)
  description = "Map of security group names to their IDs that are authorized to access the Redis-compatible Redis/Valkey cache. Format: { name = <security_group_id> }"
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
  description = "ElastiCache engine to provision: \"redis\" or \"valkey\". Valkey requires use_redis_replication_group = true because the legacy single-node resource supports Redis only. Valkey is Redis-compatible and uses the same redis:// / rediss:// URL schemes. Intended for new deployments. Do not change this on an existing stack; switching engines is not a supported in-place migration and can take API and Brainstore writes offline."
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
  description = "Valkey engine version. Used when engine = \"valkey\". Verify availability in the deployment region with the ElastiCache DescribeCacheEngineVersions API before applying."
  default     = "8.0"
}

variable "num_cache_clusters" {
  description = "Number of nodes in the replication group (primary + replicas). 1 = primary only; 2+ = active/passive with automatic failover. Only applies when use_redis_replication_group = true. The maximum supported value is 6 (one primary plus up to five replicas)."
  type        = number
  default     = 1

  validation {
    condition     = var.num_cache_clusters >= 1 && var.num_cache_clusters <= 6
    error_message = "num_cache_clusters must be between 1 and 6."
  }
}

variable "custom_tags" {
  description = "Custom tags to apply to all created resources"
  type        = map(string)
  default     = {}
}
