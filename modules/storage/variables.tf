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

variable "create_brainstore_s3_bucket" {
  type        = bool
  description = "Whether this module creates and manages the Brainstore S3 bucket. When false, existing_brainstore_s3_bucket_arn must be provided and no bucket resources are created."
  default     = true
}

variable "existing_brainstore_s3_bucket_arn" {
  type        = string
  description = "ARN of a caller-provided Brainstore S3 bucket to consume when create_brainstore_s3_bucket is false. The module reads the bucket but does not manage its lifecycle, policy, encryption, versioning, or access configuration."
  default     = null

  validation {
    condition     = var.create_brainstore_s3_bucket ? var.existing_brainstore_s3_bucket_arn == null : var.existing_brainstore_s3_bucket_arn != null
    error_message = "existing_brainstore_s3_bucket_arn must be set when create_brainstore_s3_bucket is false, and must be null when create_brainstore_s3_bucket is true."
  }
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

variable "s3_server_access_logging" {
  description = "Opt-in. Configure S3 server access logging for the brainstore, code-bundle, and lambda-responses buckets. Leave null to disable. Attach the destination bucket policy that grants s3:PutObject to logging.s3.amazonaws.com before setting this variable. The destination bucket must be in the same AWS account and region, must not have Object Lock, and must use SSE-S3 (AES256) default encryption, not SSE-KMS."
  type = object({
    bucket = string
    prefix = optional(string)
  })
  default = null

  validation {
    condition = var.s3_server_access_logging == null ? true : (
      length(var.s3_server_access_logging.bucket) > 0 && (
        var.s3_server_access_logging.prefix == null ||
        var.s3_server_access_logging.prefix == "" ||
        endswith(var.s3_server_access_logging.prefix, "/")
      )
    )
    error_message = "s3_server_access_logging.bucket must be non-empty; prefix must be null, empty, or end with '/'."
  }
}

variable "custom_tags" {
  description = "Custom tags to apply to all created resources"
  type        = map(string)
  default     = {}
}
