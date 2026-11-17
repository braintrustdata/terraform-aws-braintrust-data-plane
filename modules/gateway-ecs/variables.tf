variable "deployment_name" {
  type        = string
  description = "Name of this deployment. Will be included in resource names."
}

variable "kms_key_arn" {
  type        = string
  description = "KMS key ARN used to encrypt gateway resources that support customer-managed KMS keys."
}

variable "task_execution_role_arn" {
  type        = string
  description = "ARN of the role ECS uses to start the gateway tasks. Pass the gateway_task_execution_role_arn output of modules/iam so a task definition waits for the role's policies."
}

variable "task_role_arn" {
  type        = string
  description = "ARN of the role the gateway tasks run as. Pass the gateway_task_role_arn output of modules/iam."
}

variable "vpc_id" {
  type        = string
  description = "VPC ID where ECS resources are deployed."
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Private subnet IDs for ECS tasks and internal ALB."

  validation {
    condition     = length(var.private_subnet_ids) >= 2 && length(distinct(var.private_subnet_ids)) == length(var.private_subnet_ids)
    error_message = "private_subnet_ids must contain at least 2 unique subnet IDs."
  }
}

variable "ecs_cluster_arn" {
  type        = string
  description = "ARN of the ECS cluster where the gateway service will run."
}

variable "ecs_cluster_name" {
  type        = string
  description = "Name of the ECS cluster where the gateway service will run."
}

variable "container_image" {
  type        = string
  description = "Container image for the gateway ECS service."

  validation {
    condition     = trimspace(var.container_image) != ""
    error_message = "container_image must not be empty."
  }
}

variable "custom_ca_bundle_secret_arn" {
  type        = string
  description = "Optional ARN of the secret containing a PEM-encoded custom CA bundle."
  default     = null
}

variable "cpu" {
  type        = number
  description = "CPU units for the gateway task definition."
  default     = 2048
}

variable "memory" {
  type        = number
  description = "Memory (MiB) for the gateway task definition."
  default     = 8192
}

variable "min_capacity" {
  type        = number
  description = "Minimum number of gateway ECS tasks."
  default     = 2
}

variable "max_capacity" {
  type        = number
  description = "Maximum number of gateway ECS tasks."
  default     = 6

  validation {
    condition     = var.max_capacity >= var.min_capacity
    error_message = "max_capacity must be greater than or equal to min_capacity."
  }
}

variable "target_cpu_utilization" {
  type        = number
  description = "Target average CPU utilization percentage for gateway ECS service autoscaling."
  default     = 70

  validation {
    condition     = var.target_cpu_utilization > 0 && var.target_cpu_utilization <= 100
    error_message = "target_cpu_utilization must be between 1 and 100."
  }
}

variable "target_memory_utilization" {
  type        = number
  description = "Target average memory utilization percentage for gateway ECS service autoscaling."
  default     = 65

  validation {
    condition     = var.target_memory_utilization > 0 && var.target_memory_utilization <= 100
    error_message = "target_memory_utilization must be between 1 and 100."
  }
}

variable "log_retention_days" {
  type        = number
  description = "CloudWatch log retention days for gateway container logs."
  default     = 14

  validation {
    condition = contains([
      1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180,
      365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653
    ], var.log_retention_days)
    error_message = "log_retention_days must be a valid CloudWatch Logs retention value."
  }
}

variable "target_group_arn" {
  type        = string
  description = "ARN of the gateway ALB target group created in gateway-alb."
  nullable    = true
}

variable "alb_security_group_id" {
  type        = string
  description = "Security group ID of the gateway ALB created in gateway-alb."
  nullable    = true
}

variable "gateway_http_listener_arn" {
  type        = string
  description = "ARN of the gateway ALB HTTP listener created in gateway-alb; orders ECS registration after the listener exists."
  nullable    = true
}

variable "gateway_url" {
  type        = string
  description = "Private gateway URL that callers use after the ECS service reaches steady state."
}

variable "internal_observability_api_key_secret_arn" {
  type        = string
  description = "Secrets Manager secret ARN containing the internal observability API key."
  default     = ""
}

variable "internal_observability_api_key_secret_version" {
  type        = string
  description = "Version ID of the observability API key secret. Included in the task definition so rotating the key forces a new revision and service rollout."
  default     = ""
}

variable "internal_observability_enabled" {
  type        = bool
  description = "Whether to enable internal Datadog observability for gateway ECS."
  default     = false
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

variable "extra_env_vars" {
  type        = map(string)
  description = "Extra environment variables to inject into the gateway container."
  default     = {}

  validation {
    condition     = !contains(keys(var.extra_env_vars), "BRAINSTORE_LICENSE_KEY")
    error_message = "Do not set BRAINSTORE_LICENSE_KEY in extra_env_vars; use brainstore_license_key_secret_arn."
  }
}

variable "unsafe_url_request_mode" {
  description = "Controls how Braintrust backends handle outbound requests to user-supplied URLs that fail URL-security checks, such as URLs resolving to private or reserved IP ranges. Use off to allow, proxy to proxy, warn to allow with warnings, or reject to block. Leave empty to use the application default of warn."
  type        = string
  default     = ""

  validation {
    condition     = contains(["", "off", "proxy", "warn", "reject"], var.unsafe_url_request_mode == null ? "" : trimspace(var.unsafe_url_request_mode))
    error_message = "unsafe_url_request_mode must be empty or one of: off, proxy, warn, reject."
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

variable "org_name" {
  type        = string
  description = "Organization name allowed to use this gateway (ORG_NAME). '*' allows any name, subject to allowed_org_ids."
  default     = "*"
}

variable "allowed_org_ids" {
  type        = string
  description = "Comma-separated organization IDs allowed to use this gateway (ALLOWED_ORG_IDS), in addition to a specific org_name. Empty adds no ID restriction when org_name is '*'."
  default     = ""
}

variable "braintrust_app_url" {
  type        = string
  description = "Braintrust application URL used by the gateway."
  default     = "https://www.braintrust.dev"
}

variable "braintrust_api_url" {
  type        = string
  description = "Braintrust API URL used by the gateway."
  default     = "https://api.braintrust.dev"
}

variable "redis_url_secret_arn" {
  type        = string
  description = "ARN of the Secrets Manager secret containing the fully-rendered Redis URL. Injected into COMPLETIONS_CACHE_REDIS_URL and AUTH_CACHE_REDIS_URL via the ECS task execution role unless the caller overrides that name in extra_env_vars."
}

variable "redis_url_secret_version_id" {
  type        = string
  description = "Secrets Manager version id for the Redis URL secret. Pinned in ECS valueFrom so secret content changes create a new task definition revision."
}

variable "redis_port" {
  type        = number
  description = "Redis port used by the gateway auth cache."

  validation {
    condition     = var.redis_port >= 1 && var.redis_port <= 65535
    error_message = "redis_port must be between 1 and 65535."
  }
}

variable "redis_security_group_id" {
  type        = string
  description = "Security group ID of the dedicated gateway ElastiCache instance."
}

variable "custom_tags" {
  description = "Custom tags to apply to all created resources"
  type        = map(string)
  default     = {}
}

variable "brainstore_license_key_secret_arn" {
  type        = string
  description = "Secrets Manager secret ARN for the Brainstore license."

  validation {
    condition     = var.brainstore_license_key_secret_arn == null ? false : trimspace(var.brainstore_license_key_secret_arn) != ""
    error_message = "Provide brainstore_license_key_secret_arn for the license."
  }
}

variable "brainstore_license_key_secret_version" {
  type        = string
  description = "License secret version ID. A version change forces a new task revision and service deployment."
  default     = ""
}

variable "cpu_architecture" {
  type        = string
  description = "CPU architecture for the gateway task definition."
  default     = "ARM64"

  validation {
    condition     = contains(["ARM64", "X86_64"], var.cpu_architecture)
    error_message = "cpu_architecture must be either ARM64 or X86_64."
  }
}

variable "enable_execute_command" {
  type        = bool
  description = "Enable ECS Exec on the gateway service."
  default     = false
}

variable "additional_target_group_arns" {
  type        = map(string)
  description = "Additional target groups for the application port, keyed by load balancer name."
  default     = {}
}

variable "authorized_security_groups" {
  type        = map(string)
  description = "Additional load balancer security groups that can access the application port."
  default     = {}
}
