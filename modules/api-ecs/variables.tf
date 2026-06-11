variable "deployment_name" {
  type        = string
  description = "Name of this deployment. Will be included in resource names."
}

variable "kms_key_arn" {
  type        = string
  description = "KMS key ARN used to encrypt API ECS resources that support customer-managed KMS keys."
}

variable "vpc_id" {
  type        = string
  description = "VPC ID where ECS resources are deployed."
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Private subnet IDs for the API ECS ALB and tasks."
}

variable "ecs_cluster_arn" {
  type        = string
  description = "ARN of the ECS cluster where the API ECS service will run."
}

variable "ecs_cluster_name" {
  type        = string
  description = "Name of the ECS cluster where the API ECS service will run."
}

variable "container_image_repository" {
  type        = string
  description = "Container image repository for the API ECS service."
  default     = "public.ecr.aws/braintrust/standalone-api"

  validation {
    condition     = trimspace(var.container_image_repository) != ""
    error_message = "container_image_repository must be a non-empty string."
  }
}

variable "api_version_override" {
  type        = string
  description = "Optional API image tag override. If null, uses modules/api-ecs/VERSIONS.json."
  default     = null

  validation {
    condition     = var.api_version_override == null ? true : trimspace(var.api_version_override) != ""
    error_message = "api_version_override must be null or a non-empty string."
  }
}

variable "cpu" {
  type        = number
  description = "CPU units for the API ECS task definition."
  default     = 2048
}

variable "memory" {
  type        = number
  description = "Memory (MiB) for the API ECS task definition."
  default     = 16384
}

variable "min_count" {
  type        = number
  description = "Minimum number of API ECS tasks. Desired count is managed by Application Auto Scaling."
  default     = 3

  validation {
    condition     = var.min_count >= 1
    error_message = "min_count must be at least 1."
  }
}

variable "max_count" {
  type        = number
  description = "Maximum number of API ECS tasks."
  default     = 64

  validation {
    condition     = var.max_count >= var.min_count
    error_message = "max_count must be greater than or equal to min_count."
  }
}

variable "cpu_target_value" {
  type        = number
  description = "Target average CPU utilization percentage for API ECS autoscaling."
  default     = 40

  validation {
    condition     = var.cpu_target_value > 0 && var.cpu_target_value <= 100
    error_message = "cpu_target_value must be between 1 and 100."
  }
}

variable "memory_target_value" {
  type        = number
  description = "Target average memory utilization percentage for API ECS autoscaling."
  default     = 50

  validation {
    condition     = var.memory_target_value > 0 && var.memory_target_value <= 100
    error_message = "memory_target_value must be between 1 and 100."
  }
}

variable "log_retention_days" {
  type        = number
  description = "CloudWatch log retention days for API ECS container logs."
  default     = 14

  validation {
    condition = contains([
      1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180,
      365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653
    ], var.log_retention_days)
    error_message = "log_retention_days must be a valid CloudWatch Logs retention value."
  }
}

variable "braintrust_org_name" {
  type        = string
  description = "Braintrust organization name."
}

variable "primary_org_name" {
  type        = string
  description = "Primary organization name."
}

variable "database_url_secret_arn" {
  type        = string
  description = "ARN of the secret containing the Postgres URL."
}

variable "redis_url_secret_arn" {
  type        = string
  description = "ARN of the secret containing the Redis URL."
}

variable "response_bucket" {
  type        = string
  description = "S3 bucket for function responses."
}

variable "code_bundle_bucket" {
  type        = string
  description = "S3 bucket containing code bundles."
}

variable "function_tools_secret_arn" {
  type        = string
  description = "ARN of the function tools encryption key secret."
}

variable "brainstore_hostname" {
  type        = string
  description = "Brainstore hostname."
  default     = null
}

variable "brainstore_writer_hostname" {
  type        = string
  description = "Optional Brainstore writer hostname."
  default     = null
}

variable "brainstore_fast_reader_hostname" {
  type        = string
  description = "Optional Brainstore fast reader hostname."
  default     = null
}

variable "brainstore_s3_bucket_name" {
  type        = string
  description = "Brainstore realtime WAL S3 bucket name."
  default     = null
}

variable "brainstore_port" {
  type        = number
  description = "Brainstore port."
  default     = null
}

variable "brainstore_etl_batch_size" {
  type        = number
  description = "Batch size for Brainstore backfill operations."
  default     = null
}

variable "brainstore_wal_footer_version" {
  type        = string
  description = "Optional WAL footer version for Brainstore. Set to v1, v2, v3, or empty string to leave unset."
  default     = ""

  validation {
    condition     = var.brainstore_wal_footer_version == "" || contains(["v1", "v2", "v3"], var.brainstore_wal_footer_version)
    error_message = "brainstore_wal_footer_version must be v1, v2, v3, or empty string (unset)."
  }
}

variable "skip_pg_for_brainstore_objects" {
  type        = string
  description = "Controls which object types bypass PostgreSQL and write directly to Brainstore."
  default     = ""
}

variable "brainstore_enable_export" {
  type        = bool
  description = "If true, sets BRAINSTORE_EXPORT_MIGRATION_ENABLED=true on the API ECS container."
  default     = false
}

variable "whitelisted_origins" {
  type        = list(string)
  description = "Allowed CORS origins."
}

variable "outbound_rate_limit_window_minutes" {
  type        = number
  description = "Outbound rate limit window in minutes."
}

variable "outbound_rate_limit_max_requests" {
  type        = number
  description = "Outbound rate limit max requests."
}

variable "monitoring_telemetry" {
  type        = string
  description = "Telemetry to send to Braintrust's control plane."
}

variable "internal_observability_api_key_secret_arn" {
  type        = string
  description = "Secrets Manager secret ARN containing the internal observability API key."
  default     = ""
}

variable "internal_observability_region" {
  type        = string
  description = "Datadog region suffix (e.g. us5) used to build DD_SITE."
  default     = "us5"
}

variable "internal_observability_env_name" {
  type        = string
  description = "Datadog environment name used for DD_ENV."
  default     = ""
}

variable "internal_observability_trace_disabled_plugins" {
  type        = string
  description = "Datadog trace plugins to disable for internal observability."
  default     = ""
}

variable "disable_billing_telemetry_aggregation" {
  type        = bool
  description = "Disable billing telemetry aggregation."
}

variable "billing_telemetry_log_level" {
  type        = string
  description = "Log level for billing telemetry."
}

variable "use_quarantine_vpc" {
  type        = bool
  description = "Whether quarantine VPC resources should be exposed through API ECS env vars."
  default     = false
}

variable "quarantine_invoke_role_arn" {
  type        = string
  description = "ARN of the quarantine invoke role."
  default     = null
}

variable "quarantine_function_role_arn" {
  type        = string
  description = "ARN of the quarantine function role."
  default     = null
}

variable "quarantine_vpc_private_subnets" {
  type        = list(string)
  description = "Private subnet IDs in the quarantine VPC."
  default     = []
}

variable "quarantine_lambda_security_group_id" {
  type        = string
  description = "Security group ID used by quarantine lambdas."
  default     = null
}

variable "quarantine_vpc_id" {
  type        = string
  description = "Quarantine VPC ID."
  default     = null
}

variable "quarantine_proxy_url" {
  type        = string
  description = "URL for the AI proxy function used by quarantine execution."
}

variable "unsafe_url_request_mode" {
  description = "Controls how Braintrust backends handle outbound requests to user-supplied URLs that fail URL-security checks, such as URLs resolving to private or reserved IP ranges. Use off to allow, warn to allow with warnings, or reject to block. Leave empty to use the application default of warn."
  type        = string
  default     = ""

  validation {
    condition     = contains(["", "off", "warn", "reject"], var.unsafe_url_request_mode == null ? "" : trimspace(var.unsafe_url_request_mode))
    error_message = "unsafe_url_request_mode must be empty or one of: off, warn, reject."
  }
}

variable "url_security_dns_servers" {
  description = "Comma-separated DNS resolver IP addresses Braintrust backends should query when checking user-supplied URLs. Set this to force URL-security validation through trusted resolvers, such as VPC or corporate DNS, before falling back to the host resolver. Leave empty to use the application default resolver behavior."
  type        = string
  default     = ""
}

variable "url_security_allow_cidrs" {
  description = "Optional comma-separated CIDR ranges that Braintrust backend URL-security validation may allow even if private or reserved. Hard-blocked metadata, link-local, multicast, unspecified, and future-use ranges remain blocked."
  type        = string
  default     = ""
}

variable "extra_env_vars" {
  type        = map(string)
  description = "Extra environment variables to inject into the API ECS container."
  default     = {}
}

variable "authorized_security_groups" {
  type        = map(string)
  description = "Map of security group names to IDs authorized to access the API ECS ALB."
  default     = {}
}

variable "authorized_cidr_blocks" {
  type        = list(string)
  description = "CIDR blocks authorized to access the API ECS ALB."
  default     = []

  validation {
    condition     = alltrue([for cidr in var.authorized_cidr_blocks : can(cidrnetmask(cidr))])
    error_message = "authorized_cidr_blocks must contain valid CIDR blocks."
  }
}

variable "custom_tags" {
  description = "Custom tags to apply to all created resources."
  type        = map(string)
  default     = {}
}

variable "enable_execute_command" {
  type        = bool
  description = "Enable ECS Exec on the API ECS service."
  default     = false
}

variable "target_group_deregistration_delay_seconds" {
  type        = number
  description = "Seconds for the API ECS target group to wait before deregistering draining targets."
  default     = 300

  validation {
    condition     = var.target_group_deregistration_delay_seconds >= 0 && var.target_group_deregistration_delay_seconds <= 3600
    error_message = "target_group_deregistration_delay_seconds must be between 0 and 3600."
  }
}

variable "task_role_arn" {
  type        = string
  description = "IAM role ARN for the ECS task. Should be the APIHandlerRole ARN from the services-common module."
}

variable "task_security_group_id" {
  type        = string
  description = "Security group ID to attach to API ECS tasks."
}
