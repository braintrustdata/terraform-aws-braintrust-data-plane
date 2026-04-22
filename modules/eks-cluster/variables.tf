variable "deployment_name" {
  type        = string
  description = "Name of this deployment. Will be prefix-included in all resource names."
}

variable "custom_tags" {
  type        = map(string)
  description = "Custom tags applied to all created resources."
  default     = {}
}

variable "permissions_boundary_arn" {
  type        = string
  description = "IAM permissions boundary ARN applied to all IAM roles created by this submodule."
  default     = null
}

variable "vpc_id" {
  type        = string
  description = "VPC ID where the EKS cluster and NLB will be provisioned."
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "List of three private subnet IDs (must span AZs) for the EKS control plane ENIs, managed node group, and internal NLB."
  validation {
    condition     = length(var.private_subnet_ids) == 3
    error_message = "Exactly three private subnet IDs are required."
  }
}

variable "eks_namespace" {
  type        = string
  description = "Kubernetes namespace the Braintrust workloads run in. Used to scope IRSA trust policies to the API and Brainstore service accounts."
}

variable "api_service_account_name" {
  type        = string
  description = "Kubernetes service account name the API pod uses (matches the chart default)."
  default     = "braintrust-api"
}

variable "brainstore_service_account_name" {
  type        = string
  description = "Kubernetes service account name the Brainstore pods use (matches the chart default)."
  default     = "brainstore"
}

variable "eks_kubernetes_version" {
  type        = string
  description = "Kubernetes version for the EKS cluster."
}

variable "eks_node_instance_type" {
  type        = string
  description = "EC2 instance type for the managed node group (must support local NVMe SSD for Brainstore cache)."
}

variable "eks_node_min_size" {
  type        = number
  description = "Minimum number of nodes in the managed node group."
}

variable "eks_node_max_size" {
  type        = number
  description = "Maximum number of nodes in the managed node group."
}

variable "eks_node_desired_size" {
  type        = number
  description = "Desired number of nodes in the managed node group."
}

## CloudFront

variable "cloudfront_price_class" {
  type        = string
  description = "Price class for the CloudFront distribution."
  default     = "PriceClass_100"
}

variable "custom_domain" {
  type        = string
  description = "Optional custom domain for the CloudFront distribution."
  default     = null
}

variable "custom_certificate_arn" {
  type        = string
  description = "Optional ACM certificate ARN (us-east-1) for the custom domain."
  default     = null
}

variable "waf_acl_id" {
  type        = string
  description = "Optional WAF Web ACL ID to associate with the CloudFront distribution."
  default     = null
}
