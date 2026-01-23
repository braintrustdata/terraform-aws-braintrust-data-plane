variable "deployment_name" {
  type        = string
  description = "The name of the deployment"
}

variable "instance_type" {
  type        = string
  description = "The instance type to use for the Brainstore instances. Recommended Graviton instance type with 16GB of memory and a local SSD for cache data."
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
  description = "Extra environment variables to set for Brainstore instances"
  default     = {}
}

variable "monitoring_telemetry" {
  description = <<-EOT
    The telemetry to send to Braintrust's control plane to monitor your deployment. Should be in the form of comma-separated values.

    Available options:
    - status: Health check information (default)
    - metrics: System metrics (CPU/memory) and Braintrust-specific metrics like indexing lag (default)
    - usage: Billing usage telemetry for aggregate usage metrics
    - memprof: Memory profiling statistics and heap usage patterns
    - logs: Application logs
    - traces: Distributed tracing data
  EOT
  type        = string
  default     = "status,metrics,usage"

  validation {
    condition = var.monitoring_telemetry == "" || alltrue([
      for item in split(",", var.monitoring_telemetry) :
      contains(["metrics", "logs", "traces", "status", "memprof", "usage"], trimspace(item))
    ])
    error_message = "The monitoring_telemetry value must be a comma-separated list containing only: metrics, logs, traces, status, memprof, usage."
  }
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

variable "service_token_secret_key" {
  type        = string
  description = "The secret encryption key for SERVICE_TOKEN_SECRET_KEY. Typically this re-uses the function tools secret key."
  sensitive   = true
}

variable "brainstore_s3_bucket_arn" {
  type        = string
  description = "The ARN of the S3 bucket used by Brainstore"
}

variable "brainstore_iam_role_name" {
  type        = string
  description = "The name of the IAM role for Brainstore EC2 instances"
}

variable "brainstore_instance_security_group_id" {
  type        = string
  description = "The ID of the security group to use for the Brainstore instances"
}

variable "custom_tags" {
  description = "Custom tags to apply to all created resources"
  type        = map(string)
  default     = {}
}

variable "custom_post_install_script" {
  type        = string
  description = "Optional custom bash script to run at the end of the user-data script for additional setup or configuration. Supports multi-line scripts. For complex scripts, it's recommended to store the script in a separate file and load it using file() or templatefile(). Example: file(\"$${path.module}/scripts/brainstore-post-install.sh\")"
  default     = ""
}

variable "cache_file_size" {
  type        = string
  description = "Optional. Override the cache file size (e.g., '50gb'). If not set, automatically calculates 90% of the ephemeral storage size."
  default     = null
}

variable "role" {
  type        = string
  description = "A label for this brainstore instance group. Can be a standard role like 'Reader', 'ReaderWriter', 'Writer', or a custom identifier like 'HighMemoryWriter', etc. Used for resource naming and tagging."
}

variable "mode" {
  type        = string
  description = "The operational mode of the brainstore instances: 'reader' (read-only), 'writer' (write-only), or 'readerwriter' (both). This controls BRAINSTORE_READER_ONLY_MODE and is_dedicated_writer_node settings."
  validation {
    condition     = contains(["reader", "writer", "readerwriter"], var.mode)
    error_message = "Mode must be one of: reader, writer, readerwriter"
  }
}

variable "instance_name_suffix" {
  type        = string
  description = "Suffix to append to resource names to make them unique when multiple instances of the module are used. For example, 'reader' or 'writer'"
  default     = ""
}
