variable "deployment_name" {
  type        = string
  description = "Deployment name used for resource names and tags."
}

variable "version_tag" {
  type        = string
  description = "Published Braintrust release tag shared with Loop Runtime, including any caller version override."
}

variable "stack_name" {
  type        = string
  default     = null
  description = "Release stack name shared with its network policy. Null uses the deployment-name sandbox-service suffix."
}

variable "vpc_id" {
  type        = string
  description = "Main data-plane VPC, managed by the root module or supplied by the caller."
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Three distinct dedicated private subnets in the data-plane VPC."

  validation {
    condition     = length(var.private_subnet_ids) == 3 && length(distinct(var.private_subnet_ids)) == 3 && alltrue([for id in var.private_subnet_ids : trimspace(id) != ""])
    error_message = "Supply three distinct, nonempty private subnet IDs."
  }
  validation {
    condition     = length(setintersection(toset(compact(var.private_subnet_ids)), toset(var.data_plane_subnet_ids))) == 0
    error_message = "Sandbox Service subnets must be separate from the main application subnets."
  }
}

variable "authorized_security_groups" {
  type        = map(string)
  description = "Named caller security groups allowed to access sandbox workers over mTLS on port 9400."
  default     = {}
}

variable "instance_types" {
  type        = list(string)
  description = "Worker instance types with local NVMe storage and nested virtualization support."
  default     = ["c8id.8xlarge", "c8id.12xlarge", "c8id.16xlarge", "c8id.4xlarge", "c8id.2xlarge"]

  validation {
    condition     = length(var.instance_types) > 0 && length(distinct(var.instance_types)) == length(var.instance_types) && alltrue([for value in var.instance_types : can(regex("^c8id\\.(2|4|8|12|16|24|32|48|96)xlarge$", value))])
    error_message = "Use distinct c8id worker sizes that support local NVMe storage and nested virtualization."
  }
}

variable "sandbox_vcpu_count" {
  type        = number
  description = "Virtual CPUs per sandbox."
  default     = 1

  validation {
    condition     = var.sandbox_vcpu_count >= 1 && var.sandbox_vcpu_count <= 32 && floor(var.sandbox_vcpu_count) == var.sandbox_vcpu_count
    error_message = "sandbox_vcpu_count must be an integer from 1 through 32."
  }
}

variable "sandbox_memory_mib" {
  type        = number
  description = "Memory per sandbox in MiB."
  default     = 2048

  validation {
    condition     = var.sandbox_memory_mib >= 128 && floor(var.sandbox_memory_mib) == var.sandbox_memory_mib
    error_message = "sandbox_memory_mib must be an integer of at least 128."
  }
}

variable "checkpoint_bucket_id" {
  type        = string
  description = "Deployment-owned bucket for filesystem checkpoints, kept when the fleet is disabled."
}

variable "checkpoint_bucket_arn" {
  type        = string
  description = "ARN of the deployment-owned filesystem checkpoint bucket."
}

variable "checkpoint_bucket_kms_key_arn" {
  type        = string
  default     = null
  description = "Optional KMS key encrypting the checkpoint bucket."
}

variable "operator_role_arn" {
  type        = string
  default     = null
  description = "Optional trusted IAM role with cluster administration access."

  validation {
    condition     = var.operator_role_arn == null || can(regex("^arn:[^:]+:iam::[0-9]{12}:role/.+$", var.operator_role_arn))
    error_message = "operator_role_arn must be an IAM role ARN."
  }
}

variable "permissions_boundary_arn" {
  type        = string
  description = "Optional permissions boundary for created IAM roles."
  default     = null
}

variable "brainstore_license_key_secret_arn" {
  type        = string
  description = "Secrets Manager ARN containing the deployment license. Read by the installer at runtime."
}

variable "brainstore_license_key_secret_version" {
  type        = string
  description = "License secret version to install; changing it updates worker telemetry credentials."
}

variable "brainstore_license_key_kms_key_arn" {
  type        = string
  default     = null
  description = "Optional customer-managed KMS key for the license secret."
}

variable "monitoring_telemetry" {
  type        = string
  default     = "status,metrics,usage,traces,logs"
  description = "Value for BRAINSTORE_CONTROL_PLANE_TELEMETRY."
}

variable "internal_observability_enabled" {
  type        = bool
  default     = false
  description = "Whether internal observability delivery is enabled."
}

variable "internal_observability_env_name" {
  type        = string
  default     = ""
  description = "Environment label for internal observability."
}

variable "log_retention_days" {
  type        = number
  description = "CloudWatch retention for bootstrap function logs."
  default     = 30
}

variable "custom_tags" {
  type        = map(string)
  description = "Additional AWS resource tags."
  default     = {}
}

variable "data_plane_subnet_ids" {
  type        = list(string)
  description = "Main application subnets, which must remain separate from the three worker subnets."
}
