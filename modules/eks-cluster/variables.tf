variable "deployment_name" {
  type        = string
  description = "Name of this deployment. Prefix-included in resource names."
}

variable "custom_tags" {
  type        = map(string)
  description = "Custom tags applied to created resources."
  default     = {}
}

variable "permissions_boundary_arn" {
  type        = string
  description = "IAM permissions boundary ARN applied to created IAM roles."
  default     = null
}

variable "vpc_id" {
  type        = string
  description = "VPC ID the cluster and NLB live in."
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Three private subnet IDs (must span AZs) for the cluster, Auto Mode nodes, and internal NLB."
  validation {
    condition     = length(var.private_subnet_ids) == 3
    error_message = "Exactly three private subnet IDs are required."
  }
}

variable "eks_kubernetes_version" {
  type        = string
  description = "Kubernetes version for the EKS cluster."
}

## CloudFront

variable "cloudfront_price_class" {
  type        = string
  default     = "PriceClass_100"
  description = "Price class for the CloudFront distribution."
}

variable "custom_domain" {
  type        = string
  default     = null
  description = "Optional custom domain for the CloudFront distribution."
}

variable "custom_certificate_arn" {
  type        = string
  default     = null
  description = "Optional ACM certificate ARN (us-east-1) for the custom domain."
}

variable "waf_acl_id" {
  type        = string
  default     = null
  description = "Optional WAF Web ACL ID to associate with the CloudFront distribution."
}
