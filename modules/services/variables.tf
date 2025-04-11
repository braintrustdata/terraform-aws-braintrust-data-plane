variable "braintrust_org_name" {
  type        = string
  description = "The name of your organization in Braintrust (e.g. acme.com)"
}

variable "deployment_name" {
  type        = string
  description = "Name of this deployment. Will be included in resource names"
}

variable "service_security_group_ids" {
  type        = list(string)
  description = "The security group ids to apply to the lambda functions that are the main braintrust service"
}

variable "service_subnet_ids" {
  type        = list(string)
  description = "The subnet ids for the lambda functions that are the main braintrust service"
}

variable "service_additional_policy_arns" {
  type        = list(string)
  description = "Additional policy ARNs to attach to the lambda functions that are the main braintrust service"
  default     = []
}
variable "postgres_username" {
  type        = string
  description = "The username of the postgres database"
}

variable "postgres_password" {
  type        = string
  description = "The password of the postgres database"
  sensitive   = true
}

variable "postgres_host" {
  type        = string
  description = "The host of the postgres database, optionally including the port. Format: host[:port]"
}

variable "postgres_port" {
  type        = number
  description = "The port of the postgres database"
  default     = 5432
}

variable "redis_host" {
  type        = string
  description = "The host of the redis database"
}

variable "redis_port" {
  type        = string
  description = "The port of the redis database"
}

variable "use_quarantine_vpc" {
  type        = bool
  description = "Whether to use a quarantine VPC to allow running of user defined functions"
  default     = true
}

variable "quarantine_vpc_id" {
  type        = string
  description = "The ID of the quarantine VPC"
  default     = null
  validation {
    condition     = var.use_quarantine_vpc ? var.quarantine_vpc_id != null : true
    error_message = "Quarantine VPC ID is required when using quarantine VPC."
  }
}

variable "quarantine_vpc_default_security_group_id" {
  type        = string
  description = "The ID of the quarantine VPC default security group"
  default     = null
  validation {
    condition     = var.use_quarantine_vpc ? var.quarantine_vpc_default_security_group_id != null : true
    error_message = "Quarantine VPC default security group ID is required when using quarantine VPC."
  }
}

variable "quarantine_vpc_private_subnets" {
  type        = list(string)
  description = "The private subnets of the quarantine VPC"
  default     = []
  validation {
    condition     = var.use_quarantine_vpc ? length(var.quarantine_vpc_private_subnets) == 3 : true
    error_message = "Quarantine VPC must have 3 private subnets."
  }
}

variable "brainstore_enabled" {
  type        = bool
  description = "Whether Brainstore is enabled"
  default     = false
}

variable "brainstore_hostname" {
  type        = string
  description = "Hostname for Brainstore"
  default     = ""
  validation {
    condition     = var.brainstore_enabled ? var.brainstore_hostname != null : true
    error_message = "Brainstore hostname is required when Brainstore is enabled."
  }
}

variable "brainstore_port" {
  type        = number
  description = "Port for Brainstore"
  default     = 4000
  validation {
    condition     = var.brainstore_enabled ? var.brainstore_port != null : true
    error_message = "Brainstore port is required when Brainstore is enabled."
  }
}

variable "brainstore_s3_bucket_name" {
  type        = string
  description = "Name of the Brainstore S3 bucket"
  default     = ""
  validation {
    condition     = var.brainstore_enabled ? var.brainstore_s3_bucket_name != null : true
    error_message = "Brainstore S3 bucket name is required when Brainstore is enabled."
  }
}

variable "whitelisted_origins" {
  type        = list(string)
  description = "List of origins to whitelist for CORS"
}

variable "outbound_rate_limit_max_requests" {
  type        = number
  description = "The maximum number of requests per user allowed in the time frame specified by OutboundRateLimitMaxRequests. Setting to 0 will disable rate limits"
  default     = 0
}
variable "outbound_rate_limit_window_minutes" {
  type        = number
  description = "The time frame in minutes over which rate per-user rate limits are accumulated"
  default     = 1
}

variable "api_handler_provisioned_concurrency" {
  type        = number
  description = "The number API Handler instances to provision and keep alive. This reduces cold start times and improves latency, with some increase in cost."
  default     = 1
}

variable "run_draft_migrations" {
  type        = bool
  description = "Enable draft migrations for database schema updates"
  default     = false
}

variable "custom_domain" {
  description = "Custom domain name for the CloudFront distribution"
  type        = string
  default     = null
}

variable "custom_certificate_arn" {
  description = "ARN of the ACM certificate for the custom domain"
  type        = string
  default     = null
}

variable "kms_key_arn" {
  description = "KMS key ARN to use for encrypting resources. If not provided, the default AWS managed key is used. DO NOT change this after deployment. If you do, prior S3 objects will no longer be readable."
  type        = string
  default     = null
}

variable "clickhouse_host" {
  description = "The host of the clickhouse instance"
  type        = string
  default     = null
}

variable "clickhouse_secret" {
  description = "The secret containing the clickhouse credentials"
  type        = string
  default     = null
}

variable "brainstore_enable_historical_full_backfill" {
  type        = bool
  description = "Enable historical full backfill for Brainstore"
  default     = true
}

variable "brainstore_backfill_new_objects" {
  type        = bool
  description = "Enable backfill for new objects for Brainstore"
  default     = true
}

variable "brainstore_backfill_disable_historical" {
  type        = bool
  description = "Disable historical backfill for Brainstore"
  default     = false
}

variable "brainstore_backfill_disable_nonhistorical" {
  type        = bool
  description = "Disable non-historical backfill for Brainstore"
  default     = false
}

variable "brainstore_etl_batch_size" {
  type        = number
  description = "The batch size for the ETL process"
  default     = null
}

variable "brainstore_default" {
  type        = string
  description = "Whether to set Brainstore as the default rather than requiring users to opt-in via feature flag."
  default     = "true"
  validation {
    condition     = contains(["true", "false", "forced"], var.brainstore_default)
    error_message = "brainstore_default must be true, false, or forced."
  }
}

variable "lambda_version_tag_override" {
  description = "Optional override for the lambda version tag. If not provided, will use locked versions from VERSIONS.json"
  type        = string
  default     = null
}

