variable "deployment_name" {
  type        = string
  description = "Name of this deployment. Will be included in resource names."
}

variable "create_iam" {
  type        = bool
  description = "Create the IAM resources in this module. Every resource has its own count that combines this with its feature gate, so the module can still expose names when it creates nothing. The root module always creates IAM for now."
  default     = true
}

variable "permissions_boundary_arn" {
  type        = string
  description = "ARN of the IAM permissions boundary to apply to all IAM roles created by this module."
  default     = null
}

variable "custom_tags" {
  type        = map(string)
  description = "Custom tags to apply to the IAM roles."
  default     = {}
}

# Feature gates. These take the same values as the root module inputs of the same name.

variable "use_deployment_mode_external_eks" {
  type        = bool
  description = "Deploy to external EKS, which has no API ECS service, Brainstore deployment waiter or gateway in this module."
  default     = false
}

variable "create_ai_gateway" {
  type        = bool
  description = "Create the private gateway ECS service. Ignored when use_deployment_mode_external_eks is true."
  default     = true
}

variable "internal_observability_enabled" {
  type        = bool
  description = "Whether internal Datadog observability is enabled. Must be a plan-known boolean (do not derive it from the secret ARN)."
  default     = false
}

variable "ai_gateway_enable_execute_command" {
  type        = bool
  description = "Whether the gateway service enables ECS Exec. Grants the transcript and Exec permissions when diagnostics_transcript_log_group_name is also set."
  default     = false
}

# Resources the caller supplies. They exist before this module runs.

variable "kms_key_arn" {
  type        = string
  description = "ARN of a KMS key the caller supplies. Leave null when the root module created the key and passes it in created_resources."
  default     = null
}

variable "custom_ca_bundle_secret_arn" {
  type        = string
  description = "Optional ARN of the secret containing a PEM-encoded custom CA bundle."
  default     = null
}

variable "custom_ca_bundle_kms_key_arn" {
  type        = string
  description = "Optional ARN of the customer-managed KMS key encrypting the custom CA bundle secret."
  default     = null
}

variable "existing_brainstore_license_key_secret" {
  description = "Existing license secret and optional KMS key. Leave null when the root module created the secret and passes it in created_resources."
  type = object({
    arn         = string
    kms_key_arn = optional(string)
  })
  default = null
}

variable "diagnostics_transcript_log_group_name" {
  description = "Optional existing CloudWatch log group in this account and region for protected ECS Exec transcripts. The bootstrap owns the group. Null keeps legacy gateway Exec permissions unchanged."
  type        = string
  default     = null

  validation {
    condition     = var.diagnostics_transcript_log_group_name == null ? true : can(regex("^[A-Za-z0-9_./#-]{1,512}$", var.diagnostics_transcript_log_group_name))
    error_message = "diagnostics_transcript_log_group_name must be a nonempty exact CloudWatch log group name, without wildcards."
  }
}

variable "ai_gateway_bedrock_assume_role_arns" {
  type        = list(string)
  description = <<-EOT
    Optional allowlist of IAM role ARNs that the gateway task role may assume for Bedrock AssumeRole auth (sts:AssumeRole with ExternalId bt:*).
    When empty (default), AssumeRole remains unrestricted (Resource "*") for backward compatibility.
    When set, only matching role ARNs may be assumed. Exact ARNs and IAM Resource patterns are both accepted.
  EOT
  default     = []

  validation {
    condition = alltrue([
      for arn in var.ai_gateway_bedrock_assume_role_arns :
      can(regex("^arn:aws:iam::(\\*|[0-9]{12}):role/.+$", arn))
    ])
    error_message = "ai_gateway_bedrock_assume_role_arns entries must be IAM role ARNs or ARN patterns of the form arn:aws:iam::<account-id|*>:role/<role-name-or-pattern>."
  }
}

# Resources the root module has already created. The root passes exact values,
# so every policy keeps the exact ARN that the consuming module used before.

variable "created_resources" {
  description = <<-EOT
    Exact ARNs of the KMS key and secrets the root module created. An attribute stays null when its resource doesn't exist.
    Every policy that needs one of these waits for all of them, because Terraform tracks the whole object as one value. Keep only resources here that can't depend on any role in this module. Anything that can goes in its own input.
  EOT
  type = object({
    kms_key_arn                               = optional(string)
    database_url_secret_arn                   = optional(string)
    function_tools_secret_arn                 = optional(string)
    redis_url_secret_arn                      = optional(string)
    brainstore_license_key_secret_arn         = optional(string)
    internal_observability_api_key_secret_arn = optional(string)
  })
  default = {}
}

# The two inputs below are separate variables so that only the waiter policy
# reads fleet values. A cycle happens only when the fleets consume a role or
# profile output that waits on a policy reading fleet values. Today the fleets
# read the database port, and the database reads the monitoring role output. If
# the monitoring policy read fleet values through created_resources, that
# output would wait for the fleets and Terraform would report a cycle.

variable "brainstore_asg_names" {
  type        = list(string)
  description = "Names of the Brainstore fleet ASGs that the waiter may refresh. Only the waiter policy reads this."
  default     = []
}

variable "brainstore_deployment_log_group_arn" {
  type        = string
  description = "ARN of the waiter function's log group. Only the waiter policy reads this."
  default     = null
}
