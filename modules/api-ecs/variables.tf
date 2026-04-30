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

variable "container_port" {
  type        = number
  description = "Port exposed by the API ECS container."
  default     = 8000
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

variable "min_capacity" {
  type        = number
  description = "Minimum number of API ECS tasks."
  default     = 1
}

variable "max_capacity" {
  type        = number
  description = "Maximum number of API ECS tasks."
  default     = 4

  validation {
    condition     = var.max_capacity >= var.min_capacity
    error_message = "max_capacity must be greater than or equal to min_capacity."
  }
}

variable "target_cpu_utilization" {
  type        = number
  description = "Target average CPU utilization percentage for API ECS service autoscaling."
  default     = 40

  validation {
    condition     = var.target_cpu_utilization > 0 && var.target_cpu_utilization <= 100
    error_message = "target_cpu_utilization must be between 1 and 100."
  }
}

variable "target_memory_utilization" {
  type        = number
  description = "Target average memory utilization percentage for API ECS service autoscaling."
  default     = 50

  validation {
    condition     = var.target_memory_utilization > 0 && var.target_memory_utilization <= 100
    error_message = "target_memory_utilization must be between 1 and 100."
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

variable "postgres_username" {
  type        = string
  description = "Postgres username."
}

variable "postgres_password" {
  type        = string
  description = "Postgres password."
  sensitive   = true
}

variable "postgres_host" {
  type        = string
  description = "Postgres host."
}

variable "postgres_port" {
  type        = number
  description = "Postgres port."
}

variable "redis_host" {
  type        = string
  description = "Redis host."
}

variable "redis_port" {
  type        = number
  description = "Redis port."
}

variable "response_bucket" {
  type        = string
  description = "S3 bucket for function responses."
}

variable "code_bundle_bucket" {
  type        = string
  description = "S3 bucket containing code bundles."
}

variable "function_secret_key" {
  type        = string
  description = "Function secret key."
  sensitive   = true
}

variable "service_token_secret_key" {
  type        = string
  description = "Service token secret key."
  sensitive   = true
}

variable "brainstore_enabled" {
  type        = bool
  description = "Whether Brainstore should be enabled for the API container."

  validation {
    condition     = var.brainstore_enabled ? var.brainstore_hostname != null && var.brainstore_port != null : true
    error_message = "brainstore_hostname and brainstore_port must be set when brainstore_enabled is true."
  }
}

variable "brainstore_default" {
  type        = string
  description = "Whether Brainstore should be the default backing store."

  validation {
    condition     = contains(["true", "false", "force"], var.brainstore_default)
    error_message = "brainstore_default must be true, false, or force."
  }
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

variable "health_check_path" {
  type        = string
  description = "ALB target group health check path."
  default     = "/"
}

variable "alb_idle_timeout_seconds" {
  type        = number
  description = "ALB idle timeout in seconds."
  default     = 900
}

variable "alb_client_keep_alive_seconds" {
  type        = number
  description = "ALB client keep-alive in seconds."
  default     = 3600
}

variable "alb_deregistration_delay_seconds" {
  type        = number
  description = "ALB target group deregistration delay in seconds."
  default     = 900
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
  description = "Create and manage an ACM certificate for API ECS ALB."
  default     = false
}

variable "dns_name" {
  type        = string
  description = "Hostname label for the API ECS ALB certificate and optional Route53 alias record. Combined with route53_zone_name to produce the full DNS name."
  default     = null

  validation {
    condition     = !(var.create_acm_certificate || var.acm_certificate_arn != null || var.create_dns_record || var.require_https) || var.dns_name != null
    error_message = "dns_name is required when HTTPS or DNS records are enabled."
  }
  validation {
    condition     = var.dns_name == null || can(regex("^[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?$", var.dns_name))
    error_message = "dns_name must be a single DNS label containing only letters, numbers, and hyphens, and may not start or end with a hyphen."
  }
}

variable "route53_zone_name" {
  type        = string
  description = "Route53 hosted zone name used for ACM DNS validation records and optional API ECS ALB alias records."
  default     = null

  validation {
    condition     = !var.create_acm_certificate || var.route53_zone_name != null
    error_message = "route53_zone_name is required when create_acm_certificate is true."
  }
  validation {
    condition     = !var.create_dns_record || var.route53_zone_name != null
    error_message = "route53_zone_name is required when create_dns_record is true."
  }
  validation {
    condition     = !(var.create_acm_certificate || var.acm_certificate_arn != null || var.require_https) || var.route53_zone_name != null
    error_message = "route53_zone_name is required when HTTPS is enabled."
  }
}

variable "create_dns_record" {
  type        = bool
  description = "Create a Route53 alias record for the API ECS ALB using dns_name.route53_zone_name."
  default     = false
}

variable "require_https" {
  type        = bool
  description = "Require HTTPS listener configuration for this API ECS ALB."
  default     = false

  validation {
    condition     = !var.require_https || var.acm_certificate_arn != null || var.create_acm_certificate
    error_message = "require_https requires acm_certificate_arn or create_acm_certificate."
  }
}

variable "use_quarantine_vpc" {
  type        = bool
  description = "Whether to pass quarantine VPC configuration to the API ECS container."
  default     = false
}

variable "quarantine_vpc_id" {
  type        = string
  description = "Quarantine VPC ID."
  default     = null
}

variable "quarantine_vpc_private_subnets" {
  type        = list(string)
  description = "Private subnets of the quarantine VPC."
  default     = []
}

variable "quarantine_lambda_security_group_id" {
  type        = string
  description = "Security group ID used for quarantined functions."
  default     = null
}

variable "quarantine_invoke_role_arn" {
  type        = string
  description = "IAM role used by the API to invoke quarantined functions."
  default     = null
}

variable "quarantine_function_role_arn" {
  type        = string
  description = "IAM role used by quarantined functions."
  default     = null
}
