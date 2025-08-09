locals {
  # Lookup and choose an AZ if not provided
  private_subnet_1_az = var.private_subnet_1_az != null ? var.private_subnet_1_az : data.aws_availability_zones.available.names[0]
  private_subnet_2_az = var.private_subnet_2_az != null ? var.private_subnet_2_az : data.aws_availability_zones.available.names[1]
  private_subnet_3_az = var.private_subnet_3_az != null ? var.private_subnet_3_az : data.aws_availability_zones.available.names[2]
  public_subnet_1_az  = var.public_subnet_1_az != null ? var.public_subnet_1_az : data.aws_availability_zones.available.names[0]

  # Lookup and choose an AZ if not provided for Quarantine VPC
  quarantine_private_subnet_1_az = var.quarantine_private_subnet_1_az != null ? var.quarantine_private_subnet_1_az : data.aws_availability_zones.available.names[0]
  quarantine_private_subnet_2_az = var.quarantine_private_subnet_2_az != null ? var.quarantine_private_subnet_2_az : data.aws_availability_zones.available.names[1]
  quarantine_private_subnet_3_az = var.quarantine_private_subnet_3_az != null ? var.quarantine_private_subnet_3_az : data.aws_availability_zones.available.names[2]
  quarantine_public_subnet_1_az  = var.quarantine_public_subnet_1_az != null ? var.quarantine_public_subnet_1_az : data.aws_availability_zones.available.names[0]
}

variable "braintrust_org_name" {
  type        = string
  description = "The name of your organization in Braintrust (e.g. acme.com)"
}

variable "deployment_name" {
  type        = string
  default     = "braintrust"
  description = "Name of this Braintrust deployment. Will be included in tags and prefixes in resources names. Lowercase letter, numbers, and hyphens only. If you want multiple deployments in your same AWS account, use a unique name for each deployment."
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.deployment_name))
    error_message = "The deployment_name must contain only lowercase letters, numbers and hyphens in order to be compatible with AWS resource naming restrictions."
  }
  validation {
    condition     = length(var.deployment_name) <= 18
    error_message = "The deployment_name must be 18 characters or less."
  }
}

variable "kms_key_arn" {
  description = "Existing KMS key ARN to use for encrypting resources. If not provided, a new key will be created. DO NOT change this after deployment. If you do, it will attempt to destroy your DB and prior S3 objects will no longer be readable."
  type        = string
  default     = ""
}

variable "additional_kms_key_policies" {
  description = "Additional IAM policy statements to append to the generated KMS key."
  type        = list(any)
  default     = []
  validation {
    condition     = length(var.additional_kms_key_policies) == 0 || var.kms_key_arn == ""
    error_message = "additional_kms_key_policies can only be used with a generated KMS key"
  }
}

## NETWORKING
variable "vpc_cidr" {
  type        = string
  default     = "10.175.0.0/21"
  description = "CIDR block for the VPC"
}

variable "private_subnet_1_az" {
  type        = string
  default     = null
  description = "Availability zone for the first private subnet. Leave blank to choose the first available zone"
}

variable "private_subnet_2_az" {
  type        = string
  default     = null
  description = "Availability zone for the first private subnet. Leave blank to choose the second available zone"
}

variable "private_subnet_3_az" {
  type        = string
  default     = null
  description = "Availability zone for the third private subnet. Leave blank to choose the third available zone"
}

variable "public_subnet_1_az" {
  type        = string
  default     = null
  description = "Availability zone for the public subnet. Leave blank to choose the first available zone"
}

variable "enable_quarantine_vpc" {
  type        = bool
  description = "Enable the Quarantine VPC to run user defined functions in an isolated environment. If disabled, user defined functions will not be available."
  default     = true
}

variable "quarantine_vpc_cidr" {
  type        = string
  default     = "10.175.8.0/21"
  description = "CIDR block for the Quarantined VPC"
}

variable "quarantine_private_subnet_1_az" {
  type        = string
  default     = null
  description = "Availability zone for the first private subnet. Leave blank to choose the first available zone"
}

variable "quarantine_private_subnet_2_az" {
  type        = string
  default     = null
  description = "Availability zone for the first private subnet. Leave blank to choose the second available zone"
}

variable "quarantine_private_subnet_3_az" {
  type        = string
  default     = null
  description = "Availability zone for the third private subnet. Leave blank to choose the third available zone"
}

variable "quarantine_public_subnet_1_az" {
  type        = string
  default     = null
  description = "Availability zone for the public subnet. Leave blank to choose the first available zone"
}


## Database
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
  description = "Throughput for the RDS instance. Only applicable if storage_type is gp3."
  type        = number
  default     = 500
}

variable "postgres_version" {
  description = "PostgreSQL engine version for the RDS instance."
  type        = string
  default     = "15"
}

variable "postgres_multi_az" {
  description = "Specifies if the RDS instance is multi-AZ. Increases cost but provides higher availability. Recommended for production environments."
  type        = bool
  default     = false
}

variable "postgres_auto_minor_version_upgrade" {
  description = "Indicates that minor engine upgrades will be applied automatically to the DB instance during the maintenance window. When true you will have to set your postgres_version to only the major number or you will see drift. e.g. '15' instead of '15.7'"
  type        = bool
  default     = true
}

## Redis
variable "redis_instance_type" {
  description = "Instance type for the Redis cluster"
  type        = string
  default     = "cache.t4g.medium"
}

variable "redis_version" {
  description = "Redis engine version"
  type        = string
  default     = "7.0"
}

## Services

variable "api_handler_provisioned_concurrency" {
  description = "The number API Handler instances to provision and keep alive. This reduces cold start times and improves latency, with some increase in cost."
  type        = number
  default     = 1
}

variable "api_handler_reserved_concurrent_executions" {
  description = "The number of concurrent executions to reserve for the API Handler. Setting this will prevent the API Handler from throttling other lambdas in your account. Note this will take away from your global concurrency limit in your AWS account."
  type        = number
  default     = -1 # -1 means no reserved concurrency. Use up to the max concurrency limit in your AWS account.
}

variable "ai_proxy_reserved_concurrent_executions" {
  description = "The number of concurrent executions to reserve for the AI Proxy. Setting this will prevent the AI Proxy from throttling other lambdas in your account. Note this will take away from your global concurrency limit in your AWS account."
  type        = number
  default     = -1 # -1 means no reserved concurrency. Use up to the max concurrency limit in your AWS account.
}

# tflint-ignore: terraform_unused_declarations
variable "enable_billing_telemetry" {
  description = "DEPRECATED: Billing telemetry is now always enabled. This parameter is ignored."
  type        = bool
  default     = true
}

variable "disable_billing_telemetry_aggregation" {
  description = "Disable billing telemetry aggregation. Do not disable this unless instructed by support."
  type        = bool
  default     = false
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

variable "monitoring_telemetry" {
  description = "Support for internal monitoring telemetry. Do not set this unless instructed by support."
  type        = string
  default     = ""
}

variable "billing_telemetry_url" {
  description = "The URL endpoint for sending telemetry data. Do not change this unless instructed by support."
  type        = string
  default     = "https://www.braintrust.dev/api/billing/telemetry/v1/events"
}

variable "whitelisted_origins" {
  description = "List of origins to whitelist for CORS"
  type        = list(string)
  default     = []
}

variable "s3_additional_allowed_origins" {
  description = "Additional origins to allow for S3 bucket CORS configuration. Supports a wildcard in the domain name."
  type        = list(string)
  default     = []
}

variable "outbound_rate_limit_max_requests" {
  description = "The maximum number of requests per user allowed in the time frame specified by OutboundRateLimitMaxRequests. Setting to 0 will disable rate limits"
  type        = number
  default     = 0
}

variable "outbound_rate_limit_window_minutes" {
  description = "The time frame in minutes over which rate per-user rate limits are accumulated"
  type        = number
  default     = 1
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

variable "service_additional_policy_arns" {
  type        = list(string)
  description = "Additional policy ARNs to attach to the lambda functions that are the main braintrust service"
  default     = []
}

variable "lambda_version_tag_override" {
  description = "Optional override for the lambda version tag. Don't set this unless instructed by Braintrust."
  type        = string
  default     = null
}

## Clickhouse
variable "enable_clickhouse" {
  type        = bool
  description = "Enable Clickhouse for faster analytics"
  default     = false
}

variable "use_external_clickhouse_address" {
  type        = string
  description = "Do not change this unless instructed by Braintrust. If set, the domain name or IP of the external Clickhouse instance will be used and no internal instance will be created."
  default     = null
}

variable "clickhouse_metadata_storage_size" {
  type        = number
  description = "The size of the EBS volume to use for Clickhouse metadata"
  default     = 100
}

variable "clickhouse_instance_type" {
  type        = string
  description = "The instance type to use for the Clickhouse instance"
  default     = "c5.2xlarge"
}

## Brainstore
variable "enable_brainstore" {
  type        = bool
  description = "Enable Brainstore for faster analytics"
  default     = true
}

variable "brainstore_default" {
  type        = string
  description = "Whether to set Brainstore as the default rather than requiring users to opt-in via feature flag. Don't set this if you have a large backfill ongoing and are migrating from Clickhouse."
  default     = "force"
  validation {
    condition     = contains(["true", "false", "force"], var.brainstore_default)
    error_message = "brainstore_default must be true, false, or force."
  }
}

variable "brainstore_instance_type" {
  type        = string
  description = "The instance type to use for Brainstore reader nodes. Recommended Graviton instance type with 16GB of memory and a local SSD for cache data."
  default     = "c8gd.4xlarge"
}

variable "brainstore_instance_count" {
  type        = number
  description = "The number of Brainstore reader instances to provision"
  default     = 2
}

variable "brainstore_writer_instance_count" {
  type        = number
  description = "The number of dedicated writer nodes to create"
  default     = 1
}

variable "brainstore_writer_instance_type" {
  type        = string
  description = "The instance type to use for the Brainstore writer nodes"
  default     = "c8gd.8xlarge"
}

variable "brainstore_instance_key_pair_name" {
  type        = string
  description = "The name of the key pair to use for the Brainstore instance"
  default     = null
}

variable "brainstore_port" {
  type        = number
  description = "The port to use for the Brainstore instance"
  default     = 4000
}

variable "brainstore_license_key" {
  type        = string
  description = "The license key for the Brainstore instance"
  default     = null
}

variable "brainstore_version_override" {
  type        = string
  description = "Lock Brainstore on a specific version. Don't set this unless instructed by Braintrust."
  default     = null
}

variable "brainstore_enable_historical_full_backfill" {
  type        = bool
  description = "Enable historical full backfill for Brainstore. Don't modify this unless instructed by Braintrust."
  default     = true
}

variable "brainstore_backfill_new_objects" {
  type        = bool
  description = "Enable backfill for new objects for Brainstore. Don't modify this unless instructed by Braintrust."
  default     = true
}

variable "brainstore_etl_batch_size" {
  type        = number
  description = "The batch size for the ETL process"
  default     = null
}

variable "brainstore_s3_bucket_retention_days" {
  type        = number
  description = "The number of days to retain non-current S3 objects. e.g. deleted objects"
  default     = 7
}

variable "brainstore_vacuum_all_objects" {
  type        = bool
  description = "Enable vacuuming of all objects in Brainstore"
  default     = false
}

variable "monitoring_telemetry" {
  description = "The telemetry to send to Braintrust's control plane to monitor your deployment. Should be in the form of comma-separated values. Available options are metrics, logs, traces, status, memprof, and usage."
  type        = string
  default     = "status,metrics"
}
variable "brainstore_extra_env_vars" {
  type        = map(string)
  description = "Extra environment variables to set for Brainstore reader or dual use nodes"
  default     = {}
}

variable "brainstore_extra_env_vars_writer" {
  type        = map(string)
  description = "Extra environment variables to set for Brainstore writer nodes"
  default     = {}
}

variable "brainstore_disable_optimization_worker" {
  type        = bool
  description = "Disable the optimization worker globally in Brainstore"
  default     = false
}

variable "service_extra_env_vars" {
  type = object({
    APIHandler               = map(string)
    AIProxy                  = map(string)
    CatchupETL               = map(string)
    BillingCron              = map(string)
    MigrateDatabaseFunction  = map(string)
    QuarantineWarmupFunction = map(string)
    AutomationCron           = map(string)
  })
  description = "Extra environment variables to set for services"
  default = {
    APIHandler               = {}
    AIProxy                  = {}
    CatchupETL               = {}
    BillingCron              = {}
    MigrateDatabaseFunction  = {}
    QuarantineWarmupFunction = {}
    AutomationCron           = {}
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
