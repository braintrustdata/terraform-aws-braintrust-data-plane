variable "braintrust_org_name" {
  type        = string
  description = "The name of your organization in Braintrust (e.g. acme.com)"
}

variable "deployment_name" {
  type        = string
  description = "Name of this deployment. Will be included in resource names"
}

variable "vpc_id" {
  type        = string
  description = "The ID of the VPC to deploy the services into"
}

variable "service_subnet_ids" {
  type        = list(string)
  description = "The subnet ids for the lambda functions that are the main braintrust service"
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
  default     = true
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

variable "brainstore_writer_hostname" {
  type        = string
  description = "Hostname for the dedicated Brainstore writer nodes, if enabled"
  default     = null
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

variable "api_handler_reserved_concurrent_executions" {
  type        = number
  description = "The number of concurrent executions to reserve for the API Handler. Setting this will prevent the API Handler from throttling other lambdas in your account. Note this will take away from your global concurrency limit in your AWS account."
  default     = -1 # -1 means no reserved concurrency. Use up to the max concurrency limit in your AWS account.
}

variable "ai_proxy_reserved_concurrent_executions" {
  type        = number
  description = "The number of concurrent executions to reserve for the AI Proxy. Setting this will prevent the AI Proxy from throttling other lambdas in your account. Note this will take away from your global concurrency limit in your AWS account."
  default     = -1 # -1 means no reserved concurrency. Use up to the max concurrency limit in your AWS account.
}

variable "run_draft_migrations" {
  type        = bool
  description = "Enable draft migrations for database schema updates"
  default     = false
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


variable "brainstore_etl_batch_size" {
  type        = number
  description = "The batch size for the ETL process"
  default     = null
}

variable "brainstore_default" {
  type        = string
  description = "Whether to set Brainstore as the default rather than requiring users to opt-in via feature flag."
  default     = "force"
  validation {
    condition     = contains(["true", "false", "force"], var.brainstore_default)
    error_message = "brainstore_default must be true, false, or force."
  }
}

variable "lambda_version_tag_override" {
  description = "Optional override for the lambda version tag. If not provided, will use locked versions from VERSIONS.json"
  type        = string
  default     = null
}

variable "extra_env_vars" {
  type = object({
    APIHandler               = map(string)
    AIProxy                  = map(string)
    BillingCron              = map(string)
    CatchupETL               = map(string)
    MigrateDatabaseFunction  = map(string)
    QuarantineWarmupFunction = map(string)
    AutomationCron           = map(string)
  })
  description = "Extra environment variables to set for services"
  default = {
    APIHandler               = {}
    AIProxy                  = {}
    BillingCron              = {}
    CatchupETL               = {}
    MigrateDatabaseFunction  = {}
    QuarantineWarmupFunction = {}
    AutomationCron           = {}
  }
}

variable "disable_billing_telemetry_aggregation" {
  description = "Disable billing telemetry aggregation. Do not set as true unless instructed by support."
  type        = bool
  default     = false
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

variable "billing_telemetry_log_level" {
  description = "Log level for billing telemetry. Defaults to 'error' if empty, or unspecified."
  type        = string
  default     = ""

  validation {
    condition     = var.billing_telemetry_log_level == "" || contains(["info", "warn", "error", "debug"], var.billing_telemetry_log_level)
    error_message = "billing_telemetry_log_level must be empty or one of: info, warn, error, debug"
  }
}

variable "permissions_boundary_arn" {
  type        = string
  description = "ARN of the IAM permissions boundary to apply to all IAM roles created by this module"
  default     = null
}

variable "code_bundle_bucket_arn" {
  type        = string
  description = "The ARN of the code bundle bucket"
}

variable "lambda_responses_bucket_arn" {
  type        = string
  description = "The ARN of the lambda responses bucket"
}

variable "api_security_group_id" {
  type        = string
  description = "The ID of the security group for the API and other lambdas"
}

variable "api_handler_role_arn" {
  type        = string
  description = "The ARN of the API handler role used by the API handler lambda and various other lambdas"
  default     = null
}

variable "function_tools_secret_key" {
  type        = string
  description = "The function tools encryption key used for environment variables"
  sensitive   = true
}
