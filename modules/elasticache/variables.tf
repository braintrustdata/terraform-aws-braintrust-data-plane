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

variable "brainstore_ec2_security_group_id" {
  description = "Security Group ID for the Brainstore instances."
  type        = string
}

variable "lambda_security_group_id" {
  description = "Security Group ID for the Lambda functions."
  type        = string
}

variable "remote_support_security_group_id" {
  type        = string
  description = "Security Group ID for the Remote Support bastion host."
  default     = null
}

variable "enable_remote_support_access" {
  type        = bool
  description = "Enable remote support access to elasticache instances."
  default     = false
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
