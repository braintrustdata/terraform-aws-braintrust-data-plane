variable "deployment_name" {
  type        = string
  description = "Name of this deployment. Will be included in resource names."
}

variable "permissions_boundary_arn" {
  type        = string
  description = "ARN of the IAM permissions boundary to apply to the MicroVM build/execution roles."
  default     = null
}

variable "microvm_version_tag" {
  type        = string
  description = "Version tag of the published MicroVM guest artifact (resolves the content-addressed key via the version-<tag> pointer)."
}

variable "artifact_bucket_name" {
  type        = string
  description = "S3 bucket holding the MicroVM guest artifact. Defaults to braintrust-assets-<region>."
  default     = null
}

variable "artifact_key_prefix" {
  type        = string
  description = "Key prefix under which the MicroVM guest artifact + version pointer are published."
  default     = "microvm/loop-runtime"
}

variable "microvm_minimum_memory_mib" {
  type        = number
  description = "Minimum memory (MiB) provisioned for sandbox MicroVMs."
  default     = 2048

  validation {
    condition     = var.microvm_minimum_memory_mib >= 2048
    error_message = "microvm_minimum_memory_mib must be at least 2048."
  }
}

variable "microvm_max_idle_duration_seconds" {
  type        = number
  description = "Seconds without endpoint traffic before a sandbox MicroVM auto-suspends."
  default     = 900

  validation {
    condition     = var.microvm_max_idle_duration_seconds >= 1 && var.microvm_max_idle_duration_seconds <= 28800
    error_message = "microvm_max_idle_duration_seconds must be between 1 and 28800."
  }
}

variable "microvm_suspended_duration_seconds" {
  type        = number
  description = "Seconds a suspended sandbox MicroVM remains resumable before termination."
  default     = 28800

  validation {
    condition     = var.microvm_suspended_duration_seconds >= 1 && var.microvm_suspended_duration_seconds <= 28800
    error_message = "microvm_suspended_duration_seconds must be between 1 and 28800."
  }
}

variable "microvm_maximum_duration_seconds" {
  type        = number
  description = "Maximum sandbox MicroVM lifetime in running or suspended states."
  default     = 28800

  validation {
    condition     = var.microvm_maximum_duration_seconds >= 1 && var.microvm_maximum_duration_seconds <= 28800
    error_message = "microvm_maximum_duration_seconds must be between 1 and 28800."
  }
}

variable "microvm_auth_token_expiration_minutes" {
  type        = number
  description = "Endpoint auth token lifetime in minutes for sandbox MicroVM invocations."
  default     = 30

  validation {
    condition     = var.microvm_auth_token_expiration_minutes >= 1 && var.microvm_auth_token_expiration_minutes <= 60
    error_message = "microvm_auth_token_expiration_minutes must be between 1 and 60."
  }
}

variable "microvm_runtime_port" {
  type        = number
  description = "Port the MicroVM guest runtime listens on."
  default     = 8080
}

variable "ingress_network_connector_arns" {
  type        = list(string)
  description = "Ingress network connector ARNs used at RunMicrovm time. Defaults to the AWS-managed ALL_INGRESS connector."
  default     = []
}

variable "sandbox_egress_mode" {
  type        = string
  description = "Exactly \"internet\" uses AWS-managed Internet egress. Every other value selects the restricted egress connector."
  default     = "restricted"
}

variable "enable_microvm_runtime_logs" {
  type        = bool
  description = "Export MicroVM stdout/stderr to CloudWatch (can include sandbox output). Creates an execution role and grants the task role PassRole."
  default     = false
}

variable "log_retention_days" {
  type        = number
  description = "CloudWatch log retention days for the MicroVM image/runtime log group."
  default     = 365

  validation {
    condition = contains([
      1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180,
      365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653
    ], var.log_retention_days)
    error_message = "log_retention_days must be a valid CloudWatch Logs retention value."
  }
}

variable "kms_key_arn" {
  type        = string
  description = "KMS key ARN for encrypting the MicroVM log group. Null uses the default CloudWatch encryption."
  default     = null
}

variable "custom_tags" {
  type        = map(string)
  description = "Tags to apply to created resources."
  default     = {}
}

variable "existing_vpc_id" {
  type        = string
  description = "Optional dedicated VPC for restricted sandbox egress. Prefer the module-managed isolated VPC. This network is not for internal connectivity. The caller owns routes and DNS restrictions."
  default     = null

  validation {
    condition     = var.existing_vpc_id == null ? true : trimspace(var.existing_vpc_id) != ""
    error_message = "existing_vpc_id must be null or a nonempty VPC ID."
  }

  validation {
    condition     = var.existing_vpc_id == null || var.sandbox_egress_mode != "internet"
    error_message = "existing_vpc_id requires restricted sandbox egress."
  }
}

variable "existing_subnet_ids" {
  type        = list(string)
  description = "Private subnet IDs in the existing sandbox VPC. Supply these IDs together with existing_vpc_id."
  default     = []
  nullable    = false

  validation {
    condition     = (var.existing_vpc_id == null) == (length(var.existing_subnet_ids) == 0)
    error_message = "existing_vpc_id and existing_subnet_ids must be supplied together."
  }

  validation {
    condition = (
      length(distinct(var.existing_subnet_ids)) == length(var.existing_subnet_ids) &&
      alltrue([for id in var.existing_subnet_ids : try(trimspace(id) != "", false)])
    )
    error_message = "existing_subnet_ids must contain distinct, nonempty subnet IDs."
  }
}
