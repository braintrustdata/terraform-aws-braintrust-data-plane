variable "deployment_name" {
  type        = string
  description = "Deployment name used for resource names and tags."
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

variable "kubernetes_api_authorized_security_groups" {
  type        = map(string)
  description = "Named Terraform runner security groups allowed to reach the private Kubernetes API on TCP 443."
  default     = {}
}

variable "server_tls_secret_arn" {
  type        = string
  description = "Existing Secrets Manager server bundle with cert, key and ca_cert PEM strings."
}

variable "client_tls_secret_arn" {
  type        = string
  description = "Existing Secrets Manager client bundle with cert, key and ca_cert PEM strings."
}

variable "tls_kms_key_arn" {
  type        = string
  description = "Optional customer-managed KMS key used by both existing TLS secrets."
  default     = null
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
    condition     = var.sandbox_vcpu_count >= 1 && floor(var.sandbox_vcpu_count) == var.sandbox_vcpu_count
    error_message = "sandbox_vcpu_count must be a positive integer."
  }
}

variable "sandbox_memory_mib" {
  type        = number
  description = "Memory per sandbox in MiB."
  default     = 2048

  validation {
    condition     = var.sandbox_memory_mib >= 512 && floor(var.sandbox_memory_mib) == var.sandbox_memory_mib
    error_message = "sandbox_memory_mib must be an integer of at least 512."
  }
}

variable "permissions_boundary_arn" {
  type        = string
  description = "Optional permissions boundary for created IAM roles."
  default     = null
}

variable "log_retention_days" {
  type        = number
  description = "CloudWatch retention for EKS control plane logs."
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
