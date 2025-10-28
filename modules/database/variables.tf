variable "deployment_name" {
  type        = string
  default     = "braintrust"
  description = "Name of this Braintrust deployment. Will be included in tags and prefixes in resources names"
}

variable "postgres_instance_type" {
  description = "Instance type for the RDS instance."
  type        = string
  default     = "db.r8g.2xlarge"
}

variable "postgres_storage_size" {
  description = "Storage size (in GB) for the RDS instance."
  type        = number
  default     = 1000
}

variable "postgres_max_storage_size" {
  description = "Maximum storage size (in GB) to allow the RDS instance to auto-scale to."
  type        = number
  default     = 4000
}

variable "postgres_storage_type" {
  description = "Storage type for the RDS instance."
  type        = string
  default     = "gp3"
}

variable "postgres_storage_iops" {
  description = "Storage IOPS for the RDS instance. Only applicable if storage_type is io1, io2, or gp3. For gp3 storage with PostgreSQL, IOPS can only be specified when storage size is >= 400GB."
  type        = number
  validation {
    condition = (
      var.postgres_storage_type != "gp3" ||
      (var.postgres_storage_size < 400 && var.postgres_storage_iops == null) ||
      (var.postgres_storage_size >= 400 && var.postgres_storage_iops != null && var.postgres_storage_iops >= 12000)
    )
    error_message = "For gp3 storage with size < 400GB, IOPS must be null (AWS restriction). For gp3 storage with size >= 400GB, IOPS must be specified and >= 12000."
  }
}

variable "postgres_storage_throughput" {
  description = "Storage throughput for the RDS instance. Only applicable if storage_type is gp3. For gp3 storage with PostgreSQL, throughput can only be specified when storage size is >= 400GB."
  type        = number
  validation {
    condition = (
      var.postgres_storage_type != "gp3" ||
      (var.postgres_storage_size < 400 && var.postgres_storage_throughput == null) ||
      (var.postgres_storage_size >= 400 && var.postgres_storage_throughput != null && var.postgres_storage_throughput >= 500)
    )
    error_message = "For gp3 storage with size < 400GB, throughput must be null (AWS restriction). For gp3 storage with size >= 400GB, throughput must be specified and >= 500."
  }
}

variable "postgres_version" {
  description = "PostgreSQL engine version for the RDS instance."
  type        = string
  default     = "15"
}

variable "database_subnet_ids" {
  description = "Subnet IDs for the RDS instance."
  type        = list(string)
}

variable "existing_database_subnet_group_name" {
  description = "Optionally re-use an existing database subnet group. If not provided, a new subnet group will be created using the provided database_subnet_ids."
  type        = string
  default     = null
}

variable "vpc_id" {
  type        = string
  description = "ID of VPC where RDS will be deployed."
}

variable "authorized_security_groups" {
  type        = map(string)
  description = "Map of security group names to their IDs that are authorized to access the RDS instance. Format: { name = <security_group_id> }"
  default     = {}
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

variable "auto_minor_version_upgrade" {
  description = "Indicates that minor engine upgrades will be applied automatically to the DB instance during the maintenance window. When true you will have to set your postgres_version to only the major number or you will see drift. e.g. '15' instead of '15.7'"
  type        = bool
  default     = true
}

variable "DANGER_disable_deletion_protection" {
  description = "Disable deletion protection for the database. Do not disable this unless you fully intend to destroy the database."
  type        = bool
  default     = false
}

variable "permissions_boundary_arn" {
  type        = string
  description = "ARN of the IAM permissions boundary to apply to all IAM roles created by this module"
  default     = null
}

variable "custom_tags" {
  description = "Custom tags to apply to all created resources"
  type        = map(string)
  default     = {}
}
