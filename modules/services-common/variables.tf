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

variable "enable_brainstore_ec2_ssm" {
  description = "Optional. true will enable ssm (session manager) for the brainstore EC2s. Helpful for debugging without changing firewall rules"
  type        = bool
  default     = false
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
