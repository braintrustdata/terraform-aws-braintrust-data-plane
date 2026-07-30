variable "deployment_name" {
  type        = string
  description = "Name of this deployment. Will be included in resource names."
}

variable "kms_key_arn" {
  type        = string
  description = "KMS key ARN used to encrypt Loop runtime resources that support customer-managed KMS keys."
}

variable "permissions_boundary_arn" {
  type        = string
  description = "ARN of the IAM permissions boundary to apply to the Loop runtime task role."
  default     = null
}

variable "vpc_id" {
  type        = string
  description = "VPC ID where ECS resources are deployed."
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Private subnet IDs for ECS tasks."

  validation {
    condition     = length(var.private_subnet_ids) >= 2 && length(distinct(var.private_subnet_ids)) == length(var.private_subnet_ids)
    error_message = "private_subnet_ids must contain at least 2 unique subnet IDs."
  }
}

variable "ecs_cluster_arn" {
  type        = string
  description = "ARN of the ECS cluster where the Loop runtime service will run."
}

variable "ecs_cluster_name" {
  type        = string
  description = "Name of the ECS cluster where the Loop runtime service will run."
}

variable "container_image" {
  type        = string
  description = "Container image for the Loop runtime ECS service."

  validation {
    condition     = trimspace(var.container_image) != ""
    error_message = "container_image must not be empty."
  }
}

variable "cpu" {
  type        = number
  description = "CPU units for the Loop runtime task definition."
  default     = 2048
}

variable "memory" {
  type        = number
  description = "Memory (MiB) for the Loop runtime task definition."
  default     = 8192
}

variable "ephemeral_storage_gib" {
  type        = number
  description = "Task ephemeral storage in GiB (21-200). Null uses the Fargate default (20 GiB)."
  default     = null

  validation {
    condition     = var.ephemeral_storage_gib == null || (var.ephemeral_storage_gib >= 21 && var.ephemeral_storage_gib <= 200)
    error_message = "ephemeral_storage_gib must be between 21 and 200 when set."
  }
}

variable "min_capacity" {
  type        = number
  description = "Minimum number of Loop runtime ECS tasks."
  default     = 1
}

variable "max_capacity" {
  type        = number
  description = "Maximum number of Loop runtime ECS tasks."
  default     = 4

  validation {
    condition     = var.max_capacity >= var.min_capacity
    error_message = "max_capacity must be greater than or equal to min_capacity."
  }
}

variable "target_cpu_utilization" {
  type        = number
  description = "Target average CPU utilization percentage for Loop runtime ECS service autoscaling."
  default     = 40

  validation {
    condition     = var.target_cpu_utilization > 0 && var.target_cpu_utilization <= 100
    error_message = "target_cpu_utilization must be between 1 and 100."
  }
}

variable "target_memory_utilization" {
  type        = number
  description = "Target average memory utilization percentage for Loop runtime ECS service autoscaling."
  default     = 50

  validation {
    condition     = var.target_memory_utilization > 0 && var.target_memory_utilization <= 100
    error_message = "target_memory_utilization must be between 1 and 100."
  }
}

variable "log_retention_days" {
  type        = number
  description = "CloudWatch log retention days for Loop runtime container logs."
  default     = 14

  validation {
    condition = contains([
      1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180,
      365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653
    ], var.log_retention_days)
    error_message = "log_retention_days must be a valid CloudWatch Logs retention value."
  }
}

variable "cpu_architecture" {
  type        = string
  description = "CPU architecture for the Loop runtime task definition."
  default     = "ARM64"

  validation {
    condition     = contains(["ARM64", "X86_64"], var.cpu_architecture)
    error_message = "cpu_architecture must be either ARM64 or X86_64."
  }
}

variable "enable_execute_command" {
  type        = bool
  description = "Enable ECS Exec on the Loop runtime service."
  default     = false
}

# --- ALB wiring (from loop-runtime-alb) ---
variable "target_group_arn" {
  type        = string
  description = "ARN of the Loop runtime ALB target group."
  nullable    = true
}

variable "alb_security_group_id" {
  type        = string
  description = "Security group ID of the Loop runtime ALB."
  nullable    = true
}

variable "loop_runtime_http_listener_arn" {
  type        = string
  description = "ARN of the Loop runtime ALB HTTP listener; orders ECS registration after the listener exists."
  nullable    = true
}

# --- Sandbox seam (from loop-runtime-sandbox-* module) ---
variable "sandbox_env_vars" {
  type        = map(string)
  description = "Sandbox backend environment variables merged into the container (e.g. EXO_SANDBOX_PROVIDER + AWS_LAMBDA_MICROVM_*)."
  default     = {}
}

variable "additional_task_role_policy_json" {
  type        = string
  description = "IAM policy JSON attached to the task role for the sandbox backend (e.g. MicroVM lifecycle). Must not grant Secrets Manager access."
  default     = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
}

# --- Data-plane connectivity ---
variable "database_url_secret_arn" {
  type        = string
  description = "Secrets Manager ARN of the Postgres connection URL (BRAINSTORE_METADATA_URI / BRAINSTORE_WAL_URI)."
}

variable "redis_url_secret_arn" {
  type        = string
  description = "Secrets Manager ARN of the Redis connection URL (BRAINSTORE_XACT_MANAGER_URI / BRAINSTORE_REDIS_URI / locks)."
}

variable "function_tools_secret_arn" {
  type        = string
  description = "Secrets Manager ARN of the function-tools/service-token secret (SERVICE_TOKEN_SECRET_KEY)."
}

variable "brainstore_s3_bucket_name" {
  type        = string
  description = "Brainstore S3 bucket name (for index/WAL/locks URIs)."
}

variable "brainstore_s3_bucket_arn" {
  type        = string
  description = "Brainstore S3 bucket ARN (for the task role S3 policy)."
}

variable "code_bundle_bucket" {
  type        = string
  description = "Code bundle S3 bucket name (BRAINSTORE_CODE_BUNDLE_URI)."
}

variable "code_bundle_bucket_arn" {
  type        = string
  description = "Code bundle S3 bucket ARN (for the task role S3 policy)."
}

variable "brainstore_object_store_locks" {
  type        = bool
  description = "Use S3 object-store locks (true) vs Redis locks (false) for BRAINSTORE_LOCKS_URI."
  default     = true
}

variable "brainstore_reader_url" {
  type        = string
  description = "URL of the Brainstore reader (LOOP_RUNTIME_BRAINSTORE_READER_URL)."
}

variable "ai_proxy_url" {
  type        = string
  description = "AI proxy URL used by the Loop runtime (LOOP_RUNTIME_AI_PROXY_URL)."
}

variable "brainstore_license_key" {
  type        = string
  description = "Brainstore license key (plain env)."
  default     = null
}

variable "brainstore_disable_status_updates" {
  type        = string
  description = "Value for BRAINSTORE_DISABLE_STATUS_UPDATES."
  default     = "false"
}

variable "monitoring_telemetry" {
  type        = string
  description = "Value for BRAINSTORE_CONTROL_PLANE_TELEMETRY."
  default     = "status,metrics,usage,traces,logs"
}

# --- Service-side SG ingress targets ---
variable "database_security_group_id" {
  type        = string
  description = "Security group ID of Postgres; an ingress rule from the task SG is added when set."
  default     = null
}

variable "database_port" {
  type        = number
  description = "Postgres port."
  default     = 5432
}

variable "redis_security_group_id" {
  type        = string
  description = "Security group ID of Redis; an ingress rule from the task SG is added when set."
  default     = null
}

variable "redis_port" {
  type        = number
  description = "Redis port."
  default     = 6379
}

variable "brainstore_security_group_id" {
  type        = string
  description = "Security group ID of Brainstore instances; an ingress rule from the task SG is added when set."
  default     = null
}

variable "brainstore_port" {
  type        = number
  description = "Brainstore service port."
  default     = 4000
}

# --- Runtime config ---
variable "org_name" {
  type        = string
  description = "Org this runtime serves (ORG_NAME). '*' allows any."
  default     = "*"
}

variable "allowed_org_ids" {
  type        = string
  description = "Comma-separated allowed org IDs (ALLOWED_ORG_IDS). Empty to omit."
  default     = ""
}

variable "braintrust_api_url" {
  type        = string
  description = "Braintrust API URL (BRAINTRUST_API_URL)."
}

variable "loop_runtime_lifecycle_log" {
  type        = string
  description = "Value for LOOP_RUNTIME_LIFECYCLE_LOG (\"0\" or \"1\")."
  default     = "0"

  validation {
    condition     = contains(["0", "1"], var.loop_runtime_lifecycle_log)
    error_message = "loop_runtime_lifecycle_log must be \"0\" or \"1\"."
  }
}

variable "extra_env_vars" {
  type        = map(string)
  description = "Extra environment variables merged into the Loop runtime container (overrides core/sandbox env)."
  default     = {}

  validation {
    condition     = !contains(keys(var.extra_env_vars), "BRAINSTORE_LICENSE_KEY")
    error_message = "Do not set BRAINSTORE_LICENSE_KEY in extra_env_vars; use brainstore_license_key."
  }
}

# --- Observability ---
variable "internal_observability_enabled" {
  type        = bool
  description = "Whether to enable internal Datadog observability for the Loop runtime."
  default     = false
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
  description = "Datadog environment name used for DD_ENV / OTEL attributes."
  default     = ""
}

variable "custom_tags" {
  description = "Custom tags to apply to all created resources"
  type        = map(string)
  default     = {}
}
