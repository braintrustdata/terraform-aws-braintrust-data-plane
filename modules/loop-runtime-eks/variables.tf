variable "deployment_name" {
  type        = string
  description = "Name of this deployment. Will be included in resource names."
}

variable "permissions_boundary_arn" {
  type        = string
  description = "ARN of the IAM permissions boundary to apply to the Loop Runtime EKS role."
  default     = null
}

variable "eks_cluster_arn" {
  type        = string
  description = "Optional EKS cluster ARN used to scope Pod Identity and IRSA trust."
  default     = null
}

variable "eks_namespace" {
  type        = string
  description = "Optional Kubernetes namespace used to scope Pod Identity and IRSA trust."
  default     = null
}

variable "eks_service_account_name" {
  type        = string
  description = "Kubernetes ServiceAccount name used by the Loop Runtime workload."
}

variable "enable_eks_pod_identity" {
  type        = bool
  description = "Enable EKS Pod Identity trust for the Loop Runtime role."
  default     = false
}

variable "enable_eks_irsa" {
  type        = bool
  description = "Enable IRSA trust for the Loop Runtime role. Requires eks_cluster_arn."
  default     = false
}

variable "kms_key_arn" {
  type        = string
  description = "KMS key ARN used to encrypt the Braintrust object-storage buckets."
}

variable "brainstore_s3_bucket_arn" {
  type        = string
  description = "ARN of the Brainstore S3 bucket."
}

variable "code_bundle_s3_bucket_arn" {
  type        = string
  description = "ARN of the code-bundle S3 bucket."
}

variable "brainstore_locks_s3_path" {
  type        = string
  description = "S3 path prefix under the Brainstore bucket for BRAINSTORE_LOCKS_URI. Must match the deployment's Brainstore nodes so lock namespaces overlap."
  default     = "/locks"
}

variable "sandbox_policy_json" {
  type        = string
  description = "IAM policy JSON emitted by the AWS MicroVM sandbox module. Must not grant Secrets Manager access."
  default     = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
}

variable "custom_tags" {
  type        = map(string)
  description = "Tags to apply to the Loop Runtime EKS role and policies."
  default     = {}
}
