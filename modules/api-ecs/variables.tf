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

variable "desired_count" {
  type        = number
  description = "Fixed number of API ECS tasks."
  default     = 4

  validation {
    condition     = var.desired_count >= 1
    error_message = "desired_count must be at least 1."
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

variable "disable_billing_telemetry_aggregation" {
  type        = bool
  description = "Disable billing telemetry aggregation."
}

variable "billing_telemetry_log_level" {
  type        = string
  description = "Log level for billing telemetry."
}

variable "extra_env_vars" {
  type        = map(string)
  description = "Extra environment variables to inject into the API ECS container."
  default     = {}
}

variable "code_function_execution_mode" {
  type        = string
  description = "Controls code function execution. Use disabled to turn it off or api_ecs to run code functions inside the API ECS container. Lambda quarantine execution will be added in a future release."

  validation {
    condition     = contains(["disabled", "api_ecs"], var.code_function_execution_mode)
    error_message = "code_function_execution_mode must be one of: disabled, api_ecs."
  }
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

variable "allow_cloudfront_origin_facing_traffic" {
  type        = bool
  description = "Allow inbound traffic from CloudFront origin-facing managed prefix list to the API ECS ALB."
  default     = true
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

variable "task_role_arn" {
  type        = string
  description = "IAM role ARN for the ECS task. Should be the APIHandlerRole ARN from the services-common module."
}

variable "task_security_group_id" {
  type        = string
  description = "Security group ID to attach to API ECS tasks."
}

variable "acm_certificate_arn" {
  type        = string
  description = "Existing ACM certificate ARN for API ECS ALB HTTPS listener."
  default     = null

  validation {
    condition     = var.acm_certificate_arn == null || !var.create_acm_certificate
    error_message = "acm_certificate_arn cannot be set when create_acm_certificate is true."
  }
}

variable "create_acm_certificate" {
  type        = bool
  description = "Create an ACM certificate for API ECS ALB. DNS validation records are managed by this module unless manage_certificate_validation is false."
  default     = false
}

variable "manage_certificate_validation" {
  type        = bool
  description = "When true (default), this module creates Route53 DNS validation records and waits for the ACM certificate to be validated. Set to false to manage validation records outside this module; the caller is responsible for creating the records and an aws_acm_certificate_validation resource."
  default     = true

  validation {
    condition     = var.manage_certificate_validation || var.create_acm_certificate
    error_message = "manage_certificate_validation can only be false when create_acm_certificate is true."
  }
}

variable "fqdn" {
  type        = string
  description = "Full DNS name for the API ECS ALB certificate and preferred endpoint (e.g. 'api.sandbox.example.com'). Required when HTTPS or DNS records are enabled. When create_dns_record or manage_certificate_validation is true, the zone is derived by stripping the first label and must exist in the account."
  default     = null

  validation {
    condition     = var.fqdn == null || can(regex("^[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?(\\.[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?)+$", var.fqdn))
    error_message = "fqdn must be a valid fully-qualified domain name with at least two labels."
  }
  validation {
    condition     = !(var.create_acm_certificate || var.acm_certificate_arn != null || var.create_dns_record) || var.fqdn != null
    error_message = "fqdn is required when HTTPS or DNS records are enabled."
  }
}

variable "create_dns_record" {
  type        = bool
  description = "Create a Route53 alias record for the API ECS ALB. The Route53 zone is derived from fqdn by stripping the first label and must exist in the account."
  default     = false
}
