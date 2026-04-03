variable "deployment_name" {
  type        = string
  description = "Name of this deployment. Will be included in resource names."
}

variable "kms_key_arn" {
  type        = string
  description = "KMS key ARN used to encrypt API-ECS resources that support customer-managed KMS keys."
}

variable "vpc_id" {
  type        = string
  description = "VPC ID where ECS resources are deployed."
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Private subnet IDs for ECS tasks."
}

variable "ecs_cluster_arn" {
  type        = string
  description = "ARN of the ECS cluster where the API-ECS service will run."
}

variable "ecs_cluster_name" {
  type        = string
  description = "Name of the ECS cluster where the API-ECS service will run."
}

variable "container_image" {
  type        = string
  description = "Optional full container image override for the API-ECS service."
  default     = null

  validation {
    condition     = var.container_image == null ? true : trimspace(var.container_image) != ""
    error_message = "container_image must be null or a non-empty string."
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
  description = "Port exposed by the API-ECS container."
  default     = 8000
}

variable "cpu" {
  type        = number
  description = "CPU units for the API-ECS task definition."
  default     = 2048
}

variable "memory" {
  type        = number
  description = "Memory (MiB) for the API-ECS task definition."
  default     = 16384
}

variable "min_capacity" {
  type        = number
  description = "Minimum number of API-ECS tasks."
  default     = 1
}

variable "max_capacity" {
  type        = number
  description = "Maximum number of API-ECS tasks."
  default     = 4

  validation {
    condition     = var.max_capacity >= var.min_capacity
    error_message = "max_capacity must be greater than or equal to min_capacity."
  }
}

variable "target_cpu_utilization" {
  type        = number
  description = "Target average CPU utilization percentage for API-ECS service autoscaling."
  default     = 40

  validation {
    condition     = var.target_cpu_utilization > 0 && var.target_cpu_utilization <= 100
    error_message = "target_cpu_utilization must be between 1 and 100."
  }
}

variable "target_memory_utilization" {
  type        = number
  description = "Target average memory utilization percentage for API-ECS service autoscaling."
  default     = 50

  validation {
    condition     = var.target_memory_utilization > 0 && var.target_memory_utilization <= 100
    error_message = "target_memory_utilization must be between 1 and 100."
  }
}

variable "log_retention_days" {
  type        = number
  description = "CloudWatch log retention days for API-ECS container logs."
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
  description = "S3 bucket for lambda responses."
}

variable "code_bundle_bucket" {
  type        = string
  description = "S3 bucket containing code bundles."
}

variable "function_secret_key" {
  type        = string
  description = "Function secret key."
}

variable "service_token_secret_key" {
  type        = string
  description = "Service token secret key."
}

variable "brainstore_realtime_wal_bucket" {
  type        = string
  description = "Brainstore realtime WAL bucket."
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

variable "extra_env_vars" {
  type        = map(string)
  description = "Extra environment variables to inject into the API-ECS container."
  default     = {}
}

variable "authorized_security_groups" {
  type        = map(string)
  description = "Map of security group names to IDs authorized to access the API-ECS ALB."
  default     = {}
}

variable "allow_cloudfront_origin_facing_traffic" {
  type        = bool
  description = "Allow inbound traffic from CloudFront origin-facing managed prefix list to API-ECS ALB."
  default     = true
}

variable "custom_tags" {
  description = "Custom tags to apply to all created resources"
  type        = map(string)
  default     = {}
}

variable "cpu_architecture" {
  type        = string
  description = "CPU architecture for the API-ECS task definition."
  default     = "ARM64"

  validation {
    condition     = contains(["ARM64", "X86_64"], var.cpu_architecture)
    error_message = "cpu_architecture must be either ARM64 or X86_64."
  }
}

variable "enable_execute_command" {
  type        = bool
  description = "Enable ECS Exec on the API-ECS service."
  default     = false
}

variable "health_check_path" {
  type        = string
  description = "ALB target group health check path."
  default     = "/"
}

variable "alb_idle_timeout_seconds" {
  type        = number
  description = "ALB idle timeout in seconds."
  default     = 300
}

variable "alb_client_keep_alive_seconds" {
  type        = number
  description = "ALB client keep-alive in seconds."
  default     = 3600
}

variable "alb_deregistration_delay_seconds" {
  type        = number
  description = "ALB target group deregistration delay in seconds."
  default     = 300
}

variable "alb_enable_https" {
  type        = bool
  description = "Enable HTTPS listener on API-ECS ALB."
  default     = false
}

variable "acm_certificate_arn" {
  type        = string
  description = "Existing ACM certificate ARN for API-ECS ALB HTTPS listener."
  default     = null

  validation {
    condition     = var.acm_certificate_arn == null || !var.create_acm_certificate
    error_message = "acm_certificate_arn cannot be set when create_acm_certificate is true."
  }
}

variable "create_acm_certificate" {
  type        = bool
  description = "Create and manage ACM certificate for API-ECS ALB."
  default     = false
}

variable "create_validation_records" {
  type        = bool
  description = "When creating ACM cert, also create Route53 DNS validation records."
  default     = true

  validation {
    condition     = !(var.alb_enable_https && var.create_acm_certificate) || var.create_validation_records
    error_message = "create_validation_records must be true when alb_enable_https and create_acm_certificate are both enabled."
  }
}

variable "create_dns_record" {
  type        = bool
  description = "Create a Route53 alias record for the API-ECS ALB using alb_hostname + route53_zone_name."
  default     = false
}

variable "route53_zone_name" {
  type        = string
  description = "Route53 hosted zone name used for ACM DNS validation records."
  default     = null

  validation {
    condition     = !(var.create_acm_certificate || var.create_dns_record) || var.route53_zone_name != null
    error_message = "route53_zone_name is required when create_acm_certificate or create_dns_record is true."
  }
}

variable "alb_hostname" {
  type        = string
  description = "Hostname label for managed ACM certificate (for example: api)."
  default     = null

  validation {
    condition     = !(var.create_acm_certificate || var.create_dns_record) || var.alb_hostname != null
    error_message = "alb_hostname is required when create_acm_certificate or create_dns_record is true."
  }

  validation {
    condition     = var.alb_hostname == null || can(regex("^[A-Za-z0-9-]+$", var.alb_hostname))
    error_message = "alb_hostname must be a single hostname label (letters, numbers, hyphens) without dots."
  }
}
