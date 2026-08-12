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

variable "s3_server_access_logging_bucket" {
  description = "Name of an existing S3 bucket that receives server access logs from the brainstore, code-bundle, and lambda-responses buckets. Leave null to disable logging. The destination bucket must be in the same AWS account and region, must not have Object Lock, and must grant s3:PutObject to logging.s3.amazonaws.com. Default encryption must be SSE-S3 (AES256), not SSE-KMS."
  type        = string
  default     = null
}

variable "s3_server_access_logging_prefix" {
  description = "Key prefix for S3 server access logs. Defaults to '<deployment_name>/' when logging is enabled. Per-bucket suffixes (brainstore/, code-bundle/, lambda-responses/) are appended. Must be empty or end with '/'."
  type        = string
  default     = null

  validation {
    condition     = var.s3_server_access_logging_prefix == null ? true : (var.s3_server_access_logging_prefix == "" || endswith(var.s3_server_access_logging_prefix, "/"))
    error_message = "s3_server_access_logging_prefix must be empty or end with '/'."
  }
}

variable "custom_tags" {
  description = "Custom tags to apply to all created resources"
  type        = map(string)
  default     = {}
}
