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
  description = "Storage IOPS for the RDS instance. Only applicable if storage_type is io1, io2, or gp3."
  type        = number
  default     = 10000
}

variable "postgres_storage_throughput" {
  description = "Storage throughput for the RDS instance. Only applicable if storage_type is gp3."
  type        = number
  default     = 500
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

variable "vpc_id" {
  type        = string
  description = "ID of VPC where RDS will be deployed."
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
  description = "Enable remote support access to database instances."
  default     = false
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

variable "deletion_protection" {
  description = "Indicates that the DB instance should be protected against deletion. The database can't be deleted when this value is set to true."
  type        = bool
  default     = true
}
