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

variable "primary_org_name" {
  type        = string
  default     = ""
  description = "This is only required if you intend have multiple organizations on your data plane. Owners in this organization will have special permissions to manage data plane internals."
  validation {
    condition     = var.braintrust_org_name != "*" || trimspace(var.primary_org_name) != ""
    error_message = "primary_org_name is required when braintrust_org_name is \"*\" (multiple organizations on the data plane)."
  }
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
variable "create_vpc" {
  type        = bool
  default     = true
  description = "Whether to create a new VPC. If false, existing VPC details must be provided."
}

variable "vpc_cidr" {
  type        = string
  default     = "10.175.0.0/21"
  description = "CIDR block for the VPC (only used when create_vpc is true)"
}

# Existing VPC variables (only used when create_vpc is false)
variable "existing_vpc_id" {
  type        = string
  default     = null
  description = "ID of existing VPC to use (required when create_vpc is false)"
  validation {
    condition     = var.create_vpc || var.existing_vpc_id != null
    error_message = "existing_vpc_id is required when create_vpc is false."
  }
}

variable "existing_private_subnet_1_id" {
  type        = string
  default     = null
  description = "ID of existing private subnet 1 (required when create_vpc is false)"
  validation {
    condition     = var.create_vpc || var.existing_private_subnet_1_id != null
    error_message = "existing_private_subnet_1_id is required when create_vpc is false."
  }
}

variable "existing_private_subnet_2_id" {
  type        = string
  default     = null
  description = "ID of existing private subnet 2 (required when create_vpc is false)"
  validation {
    condition     = var.create_vpc || var.existing_private_subnet_2_id != null
    error_message = "existing_private_subnet_2_id is required when create_vpc is false."
  }
}

variable "existing_private_subnet_3_id" {
  type        = string
  default     = null
  description = "ID of existing private subnet 3 (required when create_vpc is false)"
  validation {
    condition     = var.create_vpc || var.existing_private_subnet_3_id != null
    error_message = "existing_private_subnet_3_id is required when create_vpc is false."
  }
}

variable "existing_public_subnet_1_id" {
  type        = string
  default     = null
  description = "ID of existing public subnet 1 (required when create_vpc is false)"
  validation {
    condition     = var.create_vpc || var.existing_public_subnet_1_id != null
    error_message = "existing_public_subnet_1_id is required when create_vpc is false."
  }
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
  description = "CIDR block for the Quarantined VPC (only used when creating a new quarantine VPC)"
}

# Existing Quarantine VPC variables (when provided, uses existing VPC instead of creating one)
variable "existing_quarantine_vpc_id" {
  type        = string
  default     = null
  description = "ID of existing Quarantine VPC to use. If provided, the quarantine VPC will not be created."
}

variable "existing_quarantine_private_subnet_1_id" {
  type        = string
  default     = null
  description = "ID of existing Quarantine private subnet 1 (required when existing_quarantine_vpc_id is provided)"
  validation {
    condition     = var.existing_quarantine_vpc_id == null || var.existing_quarantine_private_subnet_1_id != null
    error_message = "existing_quarantine_private_subnet_1_id is required when existing_quarantine_vpc_id is provided."
  }
}

variable "existing_quarantine_private_subnet_2_id" {
  type        = string
  default     = null
  description = "ID of existing Quarantine private subnet 2 (required when existing_quarantine_vpc_id is provided)"
  validation {
    condition     = var.existing_quarantine_vpc_id == null || var.existing_quarantine_private_subnet_2_id != null
    error_message = "existing_quarantine_private_subnet_2_id is required when existing_quarantine_vpc_id is provided."
  }
}

variable "existing_quarantine_private_subnet_3_id" {
  type        = string
  default     = null
  description = "ID of existing Quarantine private subnet 3 (required when existing_quarantine_vpc_id is provided)"
  validation {
    condition     = var.existing_quarantine_vpc_id == null || var.existing_quarantine_private_subnet_3_id != null
    error_message = "existing_quarantine_private_subnet_3_id is required when existing_quarantine_vpc_id is provided."
  }
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
  description = "Storage IOPS for the RDS instance. Only applicable if storage_type is io1, io2, or gp3. For gp3 storage with PostgreSQL, IOPS can only be specified when storage size is >= 400GB."
  type        = number
  default     = 12000
}

variable "postgres_storage_throughput" {
  description = "Throughput for the RDS instance. Only applicable if storage_type is gp3. For gp3 storage with PostgreSQL, throughput can only be specified when storage size is >= 400GB."
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

variable "database_subnet_ids" {
  type        = list(string)
  description = "Optional list of subnet IDs for the database. If not provided, uses the main VPC's private subnets."
  default     = null
}

variable "database_authorized_security_groups" {
  type        = map(string)
  description = "Map of security group names to their IDs that are authorized to access the RDS instance. Format: { name = <security_group_id> }"
  default     = {}
}

variable "existing_database_subnet_group_name" {
  type        = string
  description = "Optionally re-use an existing database subnet group. If not provided, a new subnet group will be created which is the default and preferred behavior."
  default     = null
}

variable "postgres_backup_retention_period" {
  description = "Number of days to retain automated RDS backups."
  type        = number
  default     = 14
}

variable "DANGER_disable_database_deletion_protection" {
  type        = bool
  description = "Disable deletion protection for the database. Do not disable this unless you fully intend to destroy the database."
  default     = false
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

variable "redis_authorized_security_groups" {
  type        = map(string)
  description = "Map of security group names to their IDs that are authorized to access the Redis instance. Format: { name = <security_group_id> }"
  default     = {}
}

## Services

variable "enable_llm_gateway" {
  description = "Enable ECS gateway service deployment (Fargate with private ALB)"
  type        = bool
  default     = false
}

variable "container_insights" {
  description = "CloudWatch Container Insights setting for the ECS cluster. Valid values: enabled, disabled, enhanced."
  type        = string
  default     = "enabled"

  validation {
    condition     = contains(["enabled", "disabled", "enhanced"], var.container_insights)
    error_message = "container_insights must be one of: enabled, disabled, enhanced."
  }
}

variable "gateway_version_override" {
  type        = string
  description = "Lock Gateway on a specific version. Don't set this unless instructed by Braintrust."
  default     = null

  validation {
    condition     = var.gateway_version_override == null || var.gateway_version_override != ""
    error_message = "gateway_version_override must be null or a non-empty string."
  }
}

variable "gateway_cpu" {
  description = "CPU units for the gateway ECS task definition"
  type        = number
  default     = 2048
}

variable "gateway_memory" {
  description = "Memory in MiB for the gateway ECS task definition"
  type        = number
  default     = 4096
}

variable "gateway_min_capacity" {
  description = "Minimum task count for the gateway ECS service"
  type        = number
  default     = 2
}

variable "gateway_max_capacity" {
  description = "Maximum task count for the gateway ECS service"
  type        = number
  default     = 6

  validation {
    condition     = var.gateway_max_capacity >= var.gateway_min_capacity
    error_message = "gateway_max_capacity must be greater than or equal to gateway_min_capacity."
  }
}

variable "gateway_target_cpu_utilization" {
  description = "Target average CPU utilization percentage for gateway ECS autoscaling"
  type        = number
  default     = 70

  validation {
    condition     = var.gateway_target_cpu_utilization > 0 && var.gateway_target_cpu_utilization <= 100
    error_message = "gateway_target_cpu_utilization must be between 1 and 100."
  }
}

variable "gateway_target_memory_utilization" {
  description = "Target average memory utilization percentage for gateway ECS autoscaling"
  type        = number
  default     = 75

  validation {
    condition     = var.gateway_target_memory_utilization > 0 && var.gateway_target_memory_utilization <= 100
    error_message = "gateway_target_memory_utilization must be between 1 and 100."
  }
}

variable "gateway_log_retention_days" {
  description = "CloudWatch log retention period (days) for gateway ECS logs"
  type        = number
  default     = 14

  validation {
    condition = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653
    ], var.gateway_log_retention_days)
    error_message = "gateway_log_retention_days must be a valid CloudWatch Logs retention value."
  }
}

variable "gateway_extra_env_vars" {
  description = "Extra environment variables for the gateway ECS container"
  type        = map(string)
  default     = {}

  validation {
    condition     = !contains(keys(var.gateway_extra_env_vars), "BRAINSTORE_LICENSE_KEY")
    error_message = "Do not set BRAINSTORE_LICENSE_KEY in gateway_extra_env_vars; use brainstore_license_key."
  }
}

variable "gateway_cpu_architecture" {
  description = "CPU architecture for the gateway ECS task definition."
  type        = string
  default     = "ARM64"

  validation {
    condition     = contains(["ARM64", "X86_64"], var.gateway_cpu_architecture)
    error_message = "gateway_cpu_architecture must be either ARM64 or X86_64."
  }
}

variable "gateway_authorized_security_groups" {
  description = "Map of security group names to their IDs that are authorized to access the internal gateway ALB. Format: { name = <security_group_id> }"
  type        = map(string)
  default     = {}
}

variable "gateway_enable_execute_command" {
  description = "Enable ECS Exec for gateway tasks."
  type        = bool
  default     = false
}

variable "gateway_braintrust_app_url" {
  description = "Braintrust app URL used by the gateway service."
  type        = string
  default     = "https://www.braintrust.dev"
}

variable "braintrust_api_url" {
  description = "Optional. Braintrust API URL used by the gateway when using external EKS deployment mode."
  type        = string
  default     = null

  validation {
    condition     = !(var.use_deployment_mode_external_eks && var.enable_llm_gateway) || var.braintrust_api_url != null
    error_message = "braintrust_api_url is required when use_deployment_mode_external_eks and enable_llm_gateway are both true."
  }
}

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

variable "api_handler_memory_limit" {
  type        = number
  description = "The maximum memory in MB for the API Handler."
  default     = 10240

  validation {
    condition     = var.api_handler_memory_limit > 0 && var.api_handler_memory_limit <= 10240
    error_message = "The maximum supported value by AWS Lambda is 10240 MB (10 GB)."
  }
}

variable "ai_proxy_reserved_concurrent_executions" {
  description = "The number of concurrent executions to reserve for the AI Proxy. Setting this will prevent the AI Proxy from throttling other lambdas in your account. Note this will take away from your global concurrency limit in your AWS account."
  type        = number
  default     = -1 # -1 means no reserved concurrency. Use up to the max concurrency limit in your AWS account.
}

variable "ai_proxy_memory_limit" {
  type        = number
  description = "The maximum memory in MB for the AI Proxy."
  default     = 10240

  validation {
    condition     = var.ai_proxy_memory_limit > 0 && var.ai_proxy_memory_limit <= 10240
    error_message = "The maximum supported value by AWS Lambda is 10240 MB (10 GB)."
  }
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

variable "waf_acl_id" {
  description = "Optional WAF Web ACL ID to associate with the CloudFront distribution"
  type        = string
  default     = null
}

variable "cloudfront_price_class" {
  description = "The price class for the CloudFront distribution. See https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/PriceClass.html"
  type        = string
  default     = "PriceClass_100"
}

variable "service_additional_policy_arns" {
  type        = list(string)
  description = "Additional policy ARNs to attach to the main braintrust API service"
  default     = []
}

variable "brainstore_additional_policy_arns" {
  type        = list(string)
  description = "Additional policy ARNs to attach to Brainstore"
  default     = []
}

variable "lambda_version_tag_override" {
  description = "Optional override for the lambda version tag. Don't set this unless instructed by Braintrust."
  type        = string
  default     = null
}

## Brainstore
variable "enable_brainstore" {
  type        = bool
  description = "Enable Brainstore for faster analytics"
  default     = true
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

variable "brainstore_cache_file_size_reader" {
  type        = string
  description = "Optional. Override the cache file size for reader nodes (e.g., '50gb'). If not set, automatically calculates 90% of the ephemeral storage size."
  default     = null
}

variable "brainstore_cache_file_size_writer" {
  type        = string
  description = "Optional. Override the cache file size for writer nodes (e.g., '100gb'). If not set, automatically calculates 90% of the ephemeral storage size."
  default     = null
}

variable "brainstore_locks_s3_path" {
  type        = string
  description = "S3 path prefix under the Brainstore bucket for BRAINSTORE_LOCKS_URI (the path part only, not the bucket)."
  default     = "/locks"
}

variable "brainstore_etl_batch_size" {
  type        = number
  description = "The batch size for the ETL process"
  default     = null
}

variable "brainstore_wal_footer_version" {
  type        = string
  description = "This controls the WAL footer version that should be written. When set, also enables BRAINSTORE_WAL_USE_EFFICIENT_FORMAT on the API handler. Only adjust this to 'v3' after you have successfully deployed v2.x of the data plane."
  default     = "v3"
  validation {
    condition     = var.brainstore_wal_footer_version == "" || contains(["v1", "v2", "v3"], var.brainstore_wal_footer_version)
    error_message = "brainstore_wal_footer_version must be v1, v2, v3, or empty string (unset)."
  }
}

variable "skip_pg_for_brainstore_objects" {
  type        = string
  description = "Controls which object types bypass PostgreSQL and write directly to Brainstore. WARNING: This is a one-way operation. Once migrated off Postgres, objects cannot be un-migrated without downtime. When set, also enables BRAINSTORE_ASYNC_SCORING_OBJECTS / BRAINSTORE_LOG_AUTOMATIONS_OBJECTS on Brainstore nodes."
  default     = "all"
  validation {
    condition     = var.skip_pg_for_brainstore_objects == "" || var.skip_pg_for_brainstore_objects == "all" || startswith(var.skip_pg_for_brainstore_objects, "include:") || startswith(var.skip_pg_for_brainstore_objects, "exclude:")
    error_message = "skip_pg_for_brainstore_objects must be an empty string (disabled), \"all\", or start with \"include:\" or \"exclude:\"."
  }
}

variable "brainstore_s3_bucket_retention_days" {
  type        = number
  description = "The number of days to retain non-current S3 objects. e.g. deleted objects"
  default     = 7
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

variable "brainstore_fast_reader_instance_count" {
  type        = number
  description = "The number of dedicated fast reader nodes to create"
  default     = 0
}

variable "brainstore_fast_reader_instance_type" {
  type        = string
  description = "The instance type to use for the Brainstore fast reader nodes"
  default     = "c8gd.4xlarge"
}

variable "brainstore_extra_env_vars_fast_reader" {
  type        = map(string)
  description = "Extra environment variables to set for Brainstore fast reader nodes"
  default     = {}
}

variable "brainstore_cache_file_size_fast_reader" {
  type        = string
  description = "Optional. Override the cache file size for fast reader nodes (e.g., '50gb'). If not set, automatically calculates 90% of the ephemeral storage size."
  default     = null
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

variable "permissions_boundary_arn" {
  type        = string
  description = "ARN of the IAM permissions boundary to apply to all IAM roles created by this module"
  default     = null
}

variable "use_global_ai_proxy" {
  description = "Whether to use the global Cloudflare prox. Don't enable this unless instructed by Braintrust."
  type        = bool
  default     = false
}

variable "use_deployment_mode_external_eks" {
  description = "Enable EKS deployment mode. When true, disables lambdas, ec2, and ingress submodules. It assumes an EKS deployment is being done outside of terraform."
  type        = bool
  default     = false
}

variable "existing_eks_cluster_arn" {
  description = "Optional. ARN of an existing EKS cluster to use. This is used to further restrict the trust policy for IRSA and Pod Identity for the Braintrust IAM roles. When not specified, IRSA is disabled and any EKS cluster can use Pod Identity to assume Braintrust roles."
  type        = string
  default     = null
}

variable "eks_namespace" {
  description = "Optional. Namespace to use for the EKS cluster. This is used to restrict the trust policy of IRSA and Pod Identity for the Braintrust IAM roles."
  type        = string
  default     = null
}

variable "enable_eks_pod_identity" {
  description = "Optional. If you are using EKS this will enable EKS Pod Identity for the Braintrust IAM roles."
  type        = bool
  default     = false
}

variable "enable_eks_irsa" {
  description = "Optional. If you are using EKS this will enable IRSA for the Braintrust IAM roles."
  type        = bool
  default     = false
}

variable "enable_brainstore_ec2_ssm" {
  description = "Optional. true will enable ssm (session manager) for the brainstore EC2s. Helpful for debugging without changing firewall rules"
  type        = bool
  default     = false
}

variable "custom_tags" {
  description = "Custom tags to apply to all created resources"
  type        = map(string)
  default     = {}
}

variable "brainstore_custom_post_install_script" {
  type        = string
  description = "Optional custom bash script to run at the end of the Brainstore user-data script for additional setup or configuration. Supports multi-line scripts. For complex scripts, it's recommended to store the script in a separate file and load it using file() or templatefile(). Example: file(\"$${path.module}/scripts/brainstore-post-install.sh\")"
  default     = ""
}

variable "override_api_iam_role_trust_policy" {
  type        = string
  description = "Advanced: If provided, this will completely replace the trust policy for the API handler IAM role. Must be a valid JSON string representing the IAM trust policy document."
  default     = null
}

variable "override_brainstore_iam_role_trust_policy" {
  type        = string
  description = "Advanced: If provided, this will completely replace the trust policy for the Brainstore IAM role. Must be a valid JSON string representing the IAM trust policy document."
  default     = null
}

## EKS Auto Mode (Terraform-managed cluster and Braintrust deployment)

variable "create_eks_cluster" {
  type        = bool
  default     = false
  description = "Provision an EKS Auto Mode cluster and deploy Braintrust on it. Requires use_deployment_mode_external_eks = true. Auto Mode lets AWS manage node provisioning (via Karpenter), addons, and the Load Balancer Controller — so this module only has to own the cluster IAM roles, VPC wiring, and the Braintrust-specific Helm release."
  validation {
    condition     = !var.create_eks_cluster || var.use_deployment_mode_external_eks
    error_message = "create_eks_cluster requires use_deployment_mode_external_eks = true."
  }
}

variable "eks_kubernetes_version" {
  type        = string
  default     = "1.31"
  description = "Kubernetes version for the EKS cluster."
}

variable "eks_brainstore_nodepool_instance_families" {
  type        = list(string)
  default     = ["c8gd", "c7gd", "m7gd"]
  description = "EC2 instance families Auto Mode's Karpenter may pick from for Brainstore nodes. Must be NVMe-backed families (*d.*) because Brainstore caches to local SSD. Graviton by default (matches the EC2 Brainstore defaults)."
}

variable "helm_chart_version" {
  type        = string
  default     = null
  description = "Version of the Braintrust Helm chart (`oci://public.ecr.aws/braintrust/helm`) to deploy. Required when create_eks_cluster = true."
  validation {
    condition     = !var.create_eks_cluster || (var.helm_chart_version != null && var.helm_chart_version != "")
    error_message = "helm_chart_version is required when create_eks_cluster = true."
  }
}

variable "eks_helm_values_file" {
  type        = string
  default     = null
  description = "Path to a YAML file with Helm values overrides. Idiomatic usage: `eks_helm_values_file = \"$${path.module}/values.yaml\"` to point at a file alongside your main.tf. Merged in after the module's rendered defaults (later-wins per Helm's standard merge). Anything the chart exposes is fair game — replicas, resources, annotations, nodeSelector, probes, image pins. See the Braintrust Helm chart's `values.yaml` for the schema. Leave null (default) to accept chart defaults; see the `braintrust-data-plane-eks-sandbox` example for sandbox-sized values."
}
