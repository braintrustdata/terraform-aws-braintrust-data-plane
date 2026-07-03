variable "deployment_name" {
  type        = string
  description = "The name of the deployment"
}

variable "vpc_id" {
  type        = string
  description = "The ID of the VPC where Brainstore resources will be created"
}

variable "kms_key_arn" {
  type        = string
  description = "The ARN of the KMS key to use for encrypting the Brainstore disks and S3 bucket. If not provided, AWS managed keys will be used."
}

variable "brainstore_s3_bucket_arn" {
  type        = string
  description = "The ARN of the S3 bucket used by Brainstore"
}

variable "database_secret_arn" {
  type        = string
  description = "The ARN of the secret containing database credentials"
}

variable "permissions_boundary_arn" {
  type        = string
  description = "ARN of the IAM permissions boundary to apply to all IAM roles created by this module"
  default     = null
}

variable "eks_cluster_arn" {
  type        = string
  description = "Optional. If you're using EKS this enables IRSA and EKS Pod Identity for the Braintrust IAM roles. It restricts them to this cluster."
  default     = null
}

variable "eks_namespace" {
  type        = string
  description = "Optional. If you're using EKS with IRSA or EKS Pod Identity, this restricts the IAM roles to this namespace."
  default     = null
}

variable "enable_eks_pod_identity" {
  type        = bool
  description = "Optional. If you are using EKS this will enable EKS Pod Identity for the Braintrust IAM roles."
  default     = false
}

variable "enable_eks_irsa" {
  type        = bool
  description = "Optional. If you are using EKS this will enable IRSA for the Braintrust IAM roles."
  default     = false
}

variable "enable_ecs" {
  type        = bool
  description = "Whether ECS is a compute type for this deployment. Adds ecs-tasks.amazonaws.com trust to APIHandlerRole and ECS Exec permissions."
  default     = false
}

variable "code_bundle_s3_bucket_arn" {
  type        = string
  description = "The ARN of the code bundle S3 bucket"
}

variable "lambda_responses_s3_bucket_arn" {
  type        = string
  description = "The ARN of the lambda responses S3 bucket"
}

variable "service_additional_policy_arns" {
  type        = list(string)
  description = "Additional policy ARNs to attach to the IAM role used by the main braintrust API service"
  default     = []
}

variable "brainstore_additional_policy_arns" {
  type        = list(string)
  description = "Additional policy ARNs to attach to the IAM role used by Brainstore"
  default     = []
}

variable "brainstore_enable_export" {
  type        = bool
  description = "Enable Brainstore-based export IAM permissions."
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

variable "enable_quarantine_vpc" {
  type        = bool
  description = "Whether to enable Quarantine VPC IAM resources. These are needed for running user-defined functions in an isolated environment."
  default     = false
}

variable "quarantine_vpc_id" {
  type        = string
  description = "The ID of the quarantine VPC. Required when enable_quarantine_vpc is true."
  default     = null
  validation {
    condition     = var.enable_quarantine_vpc ? var.quarantine_vpc_id != null : true
    error_message = "quarantine_vpc_id is required when enable_quarantine_vpc is true."
  }
}

variable "create_ai_gateway" {
  type        = bool
  description = "When true, create the private gateway internal ALB and target group in this module."
  default     = false
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Private subnet IDs for the gateway internal ALB."
  default     = []

  validation {
    condition     = !var.create_ai_gateway || (length(var.private_subnet_ids) >= 2 && length(distinct(var.private_subnet_ids)) == length(var.private_subnet_ids))
    error_message = "private_subnet_ids must contain at least 2 unique subnet IDs when create_ai_gateway is true."
  }
}

variable "ai_gateway_authorized_security_groups" {
  type        = map(string)
  description = "Additional security groups authorized to reach the gateway ALB on port 80."
  default     = {}
}

variable "ai_gateway_alb_client_keep_alive" {
  type        = number
  description = "Client keep-alive duration in seconds for the gateway ALB."
  default     = 4000

  validation {
    condition     = var.ai_gateway_alb_client_keep_alive >= 60 && var.ai_gateway_alb_client_keep_alive <= 604800
    error_message = "ai_gateway_alb_client_keep_alive must be between 60 and 604800 seconds."
  }
}

variable "ai_gateway_alb_idle_timeout" {
  type        = number
  description = "Idle timeout in seconds for the gateway ALB."
  default     = 3600

  validation {
    condition     = var.ai_gateway_alb_idle_timeout >= 1 && var.ai_gateway_alb_idle_timeout <= 4000
    error_message = "ai_gateway_alb_idle_timeout must be between 1 and 4000 seconds."
  }
}

variable "ai_gateway_alb_deregistration_delay" {
  type        = number
  description = "Seconds for the gateway target group to wait before deregistering draining targets."
  default     = 600

  validation {
    condition     = var.ai_gateway_alb_deregistration_delay >= 0 && var.ai_gateway_alb_deregistration_delay <= 3600
    error_message = "ai_gateway_alb_deregistration_delay must be between 0 and 3600 seconds."
  }
}
