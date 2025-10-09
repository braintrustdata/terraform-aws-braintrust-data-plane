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
