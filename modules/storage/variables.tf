variable "deployment_name" {
  type        = string
  description = "The name of the deployment"
}

variable "kms_key_arn" {
  type        = string
  description = "The ARN of the KMS key to use for encrypting the S3 buckets. If not provided, AWS managed keys will be used."
  default     = null
}

variable "brainstore_s3_bucket_retention_days" {
  type        = number
  description = "The number of days to retain non-current S3 objects in the brainstore bucket. e.g. deleted objects"
  default     = 7
}

variable "s3_additional_allowed_origins" {
  type        = list(string)
  description = "Additional origins to allow for S3 bucket CORS configuration. Supports a wildcard in the domain name."
  default     = []
}
