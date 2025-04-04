variable "deployment_name" {
  type        = string
  default     = "braintrust"
  description = "Name of this Braintrust deployment. Will be included in tags and prefixes in resources names"
}

variable "postgres_instance_type" {
  description = "Instance type for the Aurora PostgreSQL instance."
  type        = string
  default     = "db.t4g.xlarge"
}

variable "postgres_version" {
  description = "PostgreSQL engine version for the Aurora PostgreSQL cluster."
  type        = string
  default     = "15.7"
}

variable "database_subnet_ids" {
  description = "Subnet IDs for the Aurora PostgreSQL cluster."
  type        = list(string)
}

variable "database_security_group_ids" {
  description = "Security Group IDs for the Aurora PostgreSQL cluster."
  type        = list(string)
}

variable "kms_key_arn" {
  description = "KMS key ARN to use for encrypting resources. If not provided, the default AWS managed key is used. DO NOT change this after deployment. If you do, it will attempt to destroy your DB."
  type        = string
  default     = null
}

variable "backtrack_window" {
  description = "The target backtrack window in seconds. Only available for aurora engine. To disable backtracking, set this value to 0. Defaults to 0."
  type        = number
  default     = 0
}

variable "deletion_protection" {
  description = "If the DB cluster should have deletion protection enabled. The database can't be deleted when this value is set to true."
  type        = bool
  default     = false
}

variable "backup_retention_period" {
  description = "The days to retain backups for. Default is 3."
  type        = number
  default     = 3
}

variable "preferred_backup_window" {
  description = "The daily time range during which automated backups are created if automated backups are enabled using the BackupRetentionPeriod parameter."
  type        = string
  default     = "00:00-00:30"
}

variable "preferred_maintenance_window" {
  description = "The weekly time range during which system maintenance can occur, in (ddd:hh24:mi-ddd:hh24:mi) format."
  type        = string
  default     = "Mon:08:00-Mon:11:00"
}
