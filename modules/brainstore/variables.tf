variable "deployment_name" {
  type        = string
  description = "The name of the deployment"
}

variable "instance_type" {
  type        = string
  description = "The instance type to use for the Brainstore reader nodes.  Recommended Graviton instance type with 16GB of memory and a local SSD for cache data."
  default     = "c8gd.4xlarge"
}

variable "license_key" {
  type        = string
  description = "The license key for the Brainstore"
  validation {
    condition     = length(var.license_key) > 0
    error_message = "The license key cannot be empty."
  }
}

variable "instance_count" {
  type        = number
  description = "The number of reader instances to create"
  default     = 2
}

variable "port" {
  type        = number
  description = "The port to use for the Brainstore"
  default     = 4000
}

variable "version_override" {
  type        = string
  description = "Lock Brainstore on a specific version. Don't set this unless instructed by Braintrust."
  default     = null
}

variable "instance_key_pair_name" {
  type        = string
  description = "Optional. The name of the key pair to use for the Brainstore instances"
  default     = null
}

variable "kms_key_arn" {
  type        = string
  description = "The ARN of the KMS key to use for encrypting the Brainstore disks and S3 bucket. If not provided, AWS managed keys will be used."
}

variable "vpc_id" {
  type        = string
  description = "The ID of the VPC where Brainstore resources will be created"
}

variable "authorized_security_groups" {
  type        = map(string)
  description = "Map of security group names to their IDs that are authorized to access the Brainstore ELB. Format: { name = <security_group_id> }"
  default     = {}
}

variable "authorized_security_groups_ssh" {
  type        = map(string)
  description = "Map of security group names to their IDs that are authorized to access Brainstore instances via SSH. Format: { name = <security_group_id> }"
  default     = {}
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "The IDs of the private subnets where Brainstore instances will be launched"
}

# Brainstore depends on the existing Postgres database and Redis instance.
variable "database_secret_arn" {
  type        = string
  description = "The ARN of the secret containing database credentials"
}

variable "database_host" {
  type        = string
  description = "The hostname of the database"
}

variable "database_port" {
  type        = string
  description = "The port of the database"
}

variable "redis_host" {
  type        = string
  description = "The hostname of the Redis instance"
}

variable "redis_port" {
  type        = string
  description = "The port of the Redis instance"
}

variable "extra_env_vars" {
  type        = map(string)
  description = "Extra environment variables to set for Brainstore reader or dual use nodes"
  default     = {}
}

variable "extra_env_vars_writer" {
  type        = map(string)
  description = "Extra environment variables to set for Brainstore writer nodes if enabled"
  default     = {}
}

variable "writer_instance_count" {
  type        = number
  description = "The number of dedicated writer nodes to create"
  default     = 1
}

variable "writer_instance_type" {
  type        = string
  description = "The instance type to use for the Brainstore writer nodes"
  default     = "c8gd.8xlarge"
}

variable "brainstore_disable_optimization_worker" {
  type        = bool
  description = "Whether to disable the optimization worker in Brainstore"
  default     = false
}

variable "brainstore_vacuum_all_objects" {
  type        = bool
  description = "Whether to vacuum all objects in Brainstore"
  default     = false
}

variable "s3_bucket_retention_days" {
  type        = number
  description = "The number of days to retain non-current S3 objects. e.g. deleted objects"
  default     = 7
}

variable "internal_observability_api_key" {
  type        = string
  description = "Support for internal observability agent. Do not set this unless instructed by support."
  default     = ""
}

variable "internal_observability_env_name" {
  type        = string
  description = "Support for internal observability agent. Do not set this unless instructed by support."
  default     = ""
}

variable "internal_observability_region" {
  type        = string
  description = "Support for internal observability agent. Do not set this unless instructed by support."
  default     = "us5"
}
