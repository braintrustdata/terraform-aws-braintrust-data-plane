variable "deployment_name" {
  type        = string
  default     = "braintrust"
  description = "Name of this Braintrust deployment. Will be included in tags and prefixes in resources names"
}

variable "postgres_instance_type" {
  description = "Instance type for the RDS instance."
  type        = string
  default     = "db.t4g.xlarge"
}

variable "postgres_storage_size" {
  description = "Storage size (in GB) for the RDS instance."
  type        = number
  default     = 100
}

variable "postgres_max_storage_size" {
  description = "Maximum storage size (in GB) to allow the RDS instance to auto-scale to."
  type        = number
  default     = 1000
}

variable "postgres_storage_type" {
  description = "Storage type for the RDS instance."
  type        = string
  default     = "gp3"
}

variable "postgres_storage_iops" {
  description = "Storage IOPS for the RDS instance. Only applicable if storage_type is io1, io2, or gp3."
  type        = number
  default     = null
}

variable "postgres_storage_throughput" {
  description = "Storage throughput for the RDS instance. Only applicable if storage_type is gp3."
  type        = number
  default     = null
}

variable "postgres_version" {
  description = "PostgreSQL engine version for the RDS instance."
  type        = string
  default     = "15.7"
}

variable "database_subnet_ids" {
  description = "Subnet IDs for the RDS instance."
  type        = list(string)
}

variable "database_security_group_ids" {
  description = "Security Group IDs for the RDS instance."
  type        = list(string)
}

variable "kms_key_arn" {
  description = "KMS key ARN to use for encrypting resources. If not provided, the default AWS managed key is used. DO NOT change this after deployment. If you do, it will attempt to destroy your DB."
  type        = string
  default     = null
}

variable "multi_az" {
  description = "Specifies if the RDS instance is multi-AZ. Increases cost but provides higher availability. Recommended for production environments."
  type        = bool
  default     = false
}
