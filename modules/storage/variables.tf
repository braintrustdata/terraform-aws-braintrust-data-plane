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
  description = "Additional CORS origins applied to both the code bundle and lambda responses buckets. Merged with any bucket-specific values from s3_code_bundle_additional_allowed_origins and s3_lambda_responses_additional_allowed_origins. Supports wildcards in the domain name."
  type        = list(string)
  default     = []
}

variable "s3_code_bundle_additional_allowed_origins" {
  description = "Additional CORS origins for the code bundle bucket. Supports wildcards in the domain name."
  type        = list(string)
  default     = []
}

variable "s3_lambda_responses_additional_allowed_origins" {
  description = "Additional CORS origins for the lambda responses bucket. Supports wildcards in the domain name."
  type        = list(string)
  default     = []
}

variable "enable_s3_bucket_abac" {
  description = "Enable attribute-based access control (ABAC) on S3 buckets managed by this module."
  type        = bool
  default     = false
}

variable "custom_tags" {
  description = "Custom tags to apply to all created resources"
  type        = map(string)
  default     = {}
}
