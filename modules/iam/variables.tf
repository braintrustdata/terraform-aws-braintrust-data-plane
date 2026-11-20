variable "deployment_name" {
  type        = string
  description = "Name of this deployment. Will be included in resource names."
}

variable "create_iam" {
  type        = bool
  description = "Create the IAM resources in this module. Every resource has its own count that combines this with its feature gate. When false, the module creates nothing. It looks up each role and instance profile that the deployment needs, by name or by an existing_iam ARN, checks that security owns it, and exposes the same outputs."
  default     = true
}

variable "iam_owner" {
  type        = string
  description = <<-EOT
    Who runs this module. The root module's managed call leaves the default, "braintrust". A security team that runs this module on its own sets "customer".
    With "customer", every role, managed policy and instance profile carries BraintrustIAMOwner = "customer", policies scope module-created resources by deterministic prefixes, the KMS alias and tags instead of exact ARNs from created_resources, and the module creates neither the default role nor the AIProxy invoke role.
  EOT
  default     = "braintrust"
  nullable    = false

  validation {
    condition     = contains(["braintrust", "customer"], var.iam_owner)
    error_message = "iam_owner must be \"braintrust\" or \"customer\"."
  }

  validation {
    condition     = var.iam_owner != "customer" || var.enable_ecs_api
    error_message = "iam_owner = \"customer\" requires enable_ecs_api = true. External IAM mode requires ECS ingress, because the Lambda ingress path writes Lambda resource policies that security can't own yet."
  }

  validation {
    condition     = var.iam_owner != "customer" || var.create_iam
    error_message = "iam_owner = \"customer\" requires create_iam = true. A standalone run always creates IAM, and setting create_iam to false later would destroy every role that security created."
  }
}

variable "region" {
  type        = string
  description = "AWS region that the deployment runs in. Policy scopes use it, so they don't depend on the credentials of whoever runs this module. A check fails when it differs from the provider's region."

  validation {
    condition     = can(regex("^[a-z]{2}(-[a-z]+)+-[0-9]+$", var.region))
    error_message = "region must be an AWS region name, such as us-east-1."
  }
}

variable "account_id" {
  type        = string
  description = "ID of the AWS account that the deployment runs in. Policy scopes use it, so they don't depend on the credentials of whoever runs this module. A check fails when it differs from the provider's account."

  validation {
    condition     = can(regex("^[0-9]{12}$", var.account_id))
    error_message = "account_id must be a 12-digit AWS account ID."
  }
}

# The keys below are the roles and instance profile that external mode can need. The default and AIProxy invoke roles are managed-only, so they have no key.

variable "override_iam_names" {
  type        = map(map(string))
  description = <<-EOT
    Sparse name and path overrides, keyed "role.<key>" or "instance_profile.brainstore". Each entry accepts "name" and "path". A field you leave out keeps its default. A security team that runs this module on its own passes the same map as the root module's override_iam_names, so the names it creates match the names infrastructure looks up. The root module never passes it in managed mode.
  EOT
  default     = {}
  nullable    = false

  # Keep this list in step with external_role_gates in lookups.tf, and with the
  # list in the existing_iam validation below.
  validation {
    condition = alltrue([
      for key in keys(var.override_iam_names) : contains([
        "role.api_handler", "role.api_ecs_task_execution", "role.brainstore", "role.quarantine_invoke", "role.quarantine_function",
        "role.gateway_task_execution", "role.gateway_task", "role.db_monitoring", "role.brainstore_deployment_waiter",
        "role.automation_cron", "role.billing_cron", "role.catchup_etl", "role.migrate_database", "role.quarantine_pruner",
        "role.quarantine_warmup", "role.automation_cron_schedule", "role.billing_cron_schedule", "role.catchup_etl_schedule",
        "role.quarantine_pruner_schedule", "instance_profile.brainstore",
      ], key)
    ])
    error_message = "override_iam_names accepts only role.<key> for a role that external mode looks up (see the Role keys table in MIGRATION_V8.md), and instance_profile.brainstore. The default and AIProxy invoke roles can't be overridden."
  }

  validation {
    condition     = alltrue([for entry in values(var.override_iam_names) : alltrue([for field in keys(entry) : contains(["name", "path"], field)])])
    error_message = "Each override_iam_names entry accepts only name and path."
  }

  validation {
    condition = alltrue([
      for key, entry in var.override_iam_names :
      !contains(keys(entry), "name") || can(regex(startswith(key, "role.") ? "^[A-Za-z0-9+=,.@_-]{1,64}$" : "^[A-Za-z0-9+=,.@_-]{1,128}$", entry.name))
    ])
    error_message = "An override_iam_names name must be 1 to 64 characters for a role, or 1 to 128 for an instance profile, from letters, digits and + = , . @ _ -."
  }

  validation {
    condition = alltrue([
      for entry in values(var.override_iam_names) :
      !contains(keys(entry), "path") || can(regex("^(/|/[!-~]{1,510}/)$", entry.path))
    ])
    error_message = "An override_iam_names path must be \"/\", or start and end with a slash and have 1 to 510 printable characters between them."
  }
}

variable "existing_iam" {
  type        = map(map(string))
  description = <<-EOT
    Exact references for roles and the instance profile that name lookup can't find, keyed the same way as override_iam_names. A role entry accepts "arn". The instance profile entry accepts "arn" or "name". Only valid when create_iam is false. The module reads each reference back and checks ownership as it does for a lookup by name.
  EOT
  default     = {}
  nullable    = false

  validation {
    condition     = !var.create_iam || length(var.existing_iam) == 0
    error_message = "existing_iam is only valid when create_iam is false. A module that creates IAM chooses the names."
  }

  # Keep this list in step with external_role_gates in lookups.tf, and with the
  # list in the override_iam_names validation above.
  validation {
    condition = alltrue([
      for key in keys(var.existing_iam) : contains([
        "role.api_handler", "role.api_ecs_task_execution", "role.brainstore", "role.quarantine_invoke", "role.quarantine_function",
        "role.gateway_task_execution", "role.gateway_task", "role.db_monitoring", "role.brainstore_deployment_waiter",
        "role.automation_cron", "role.billing_cron", "role.catchup_etl", "role.migrate_database", "role.quarantine_pruner",
        "role.quarantine_warmup", "role.automation_cron_schedule", "role.billing_cron_schedule", "role.catchup_etl_schedule",
        "role.quarantine_pruner_schedule", "instance_profile.brainstore",
      ], key)
    ])
    error_message = "existing_iam accepts only role.<key> for a role that external mode looks up (see the Role keys table in MIGRATION_V8.md), and instance_profile.brainstore. The default and AIProxy invoke roles aren't looked up."
  }

  validation {
    condition = alltrue([
      for key, entry in var.existing_iam :
      alltrue([for field in keys(entry) : contains(startswith(key, "role.") ? ["arn"] : ["arn", "name"], field)])
    ])
    error_message = "A role entry in existing_iam accepts only arn. The instance profile entry accepts arn or name."
  }

  validation {
    condition = alltrue([
      for key, entry in var.existing_iam :
      !contains(keys(entry), "arn") || can(regex(
        startswith(key, "role.") ? "^arn:aws[a-z-]*:iam::[0-9]{12}:role(/[!-~]+)?/[A-Za-z0-9+=,.@_-]{1,64}$" : "^arn:aws[a-z-]*:iam::[0-9]{12}:instance-profile(/[!-~]+)?/[A-Za-z0-9+=,.@_-]{1,128}$",
        entry.arn
      ))
    ])
    error_message = "An existing_iam arn must be an IAM role ARN for a role, or an instance profile ARN for the instance profile, with the account ID and the name in the usual places."
  }

  validation {
    # try() because || doesn't short-circuit, and an entry without arn or name has nothing to compare.
    condition = alltrue([
      for key, entry in var.existing_iam :
      try(endswith(entry.arn, "/${entry.name}"), true)
    ])
    error_message = "An existing_iam entry that sets both arn and name must name the same instance profile."
  }

  validation {
    condition = alltrue([
      for key, entry in var.existing_iam :
      try(endswith(entry.arn, "/${var.override_iam_names[key].name}"), true)
    ])
    error_message = "An override_iam_names name contradicts the existing_iam arn for the same key. Remove one of them, or make them name the same role."
  }

  # The path in the ARN is everything between the resource type and the name.
  validation {
    condition = alltrue([
      for key, entry in var.existing_iam :
      try(regex("^arn:[^:]+:iam::[0-9]{12}:(?:role|instance-profile)(/(?:.*/)?)[^/]+$", entry.arn)[0] == var.override_iam_names[key].path, true)
    ])
    error_message = "An override_iam_names path contradicts the path in the existing_iam arn for the same key. Remove one of them, or make them agree."
  }
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

variable "enable_ecs_api" {
  type        = bool
  description = "Send customer traffic to API ECS instead of the APIHandler and AIProxy Lambdas. The AIProxy invoke role exists only when this is false. Ignored when use_deployment_mode_external_eks is true."
  default     = true
}

variable "enable_quarantine_vpc" {
  type        = bool
  description = "Whether the deployment has a quarantine VPC. Gates the quarantine roles and the APIHandler quarantine policy."
  default     = false
}

variable "enable_quarantine_pruner" {
  type        = bool
  description = "Whether the quarantine pruner function is deployed. Gates its role."
  default     = false
}

variable "enable_brainstore_ec2_ssm" {
  type        = bool
  description = "Attach the SSM managed instance policy to the Brainstore role and grant transcript delivery when diagnostics_transcript_log_group_name is also set."
  default     = false
}

variable "brainstore_enable_export" {
  type        = bool
  description = "Grant the Brainstore role the S3 export AssumeRole permission."
  default     = false
}

variable "api_ecs_enable_execute_command" {
  type        = bool
  description = "Whether API ECS Exec is enabled. Grants the API role transcript delivery when diagnostics_transcript_log_group_name is also set."
  default     = false
}

# Trust, attachments and export scope for the shared API and Brainstore roles.
# These take the same values as the root module inputs of the same name, except
# eks_cluster_arn, which the root module calls existing_eks_cluster_arn.

variable "eks_cluster_arn" {
  type        = string
  description = "Optional. If you're using EKS this enables IRSA and EKS Pod Identity for the shared API and Brainstore roles. It restricts them to this cluster."
  default     = null
}

variable "eks_namespace" {
  type        = string
  description = "Optional. If you're using EKS with IRSA or EKS Pod Identity, this restricts the shared API and Brainstore roles to this namespace."
  default     = null
}

variable "enable_eks_pod_identity" {
  type        = bool
  description = "Optional. If you are using EKS this will enable EKS Pod Identity for the shared API and Brainstore roles."
  default     = false
}

variable "enable_eks_irsa" {
  type        = bool
  description = "Optional. If you are using EKS this will enable IRSA for the shared API and Brainstore roles."
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

variable "service_additional_policy_arns" {
  type        = list(string)
  description = "Additional policy ARNs to attach to the shared API role."
  default     = []
}

variable "brainstore_additional_policy_arns" {
  type        = list(string)
  description = "Additional policy ARNs to attach to the Brainstore role."
  default     = []
}

variable "s3_export_assume_role_arns" {
  type        = list(string)
  description = <<-EOT
    Optional allowlist of IAM role ARNs that the shared API and Brainstore roles may assume for S3 export (sts:AssumeRole with ExternalId bt:*).
    When empty (default), AssumeRole remains unrestricted (Resource "*") for backward compatibility.
    When set, only matching role ARNs may be assumed. Exact ARNs and IAM Resource patterns are both accepted.
  EOT
  default     = []

  validation {
    condition = alltrue([
      for arn in var.s3_export_assume_role_arns :
      can(regex("^arn:aws:iam::(\\*|[0-9]{12}):role/.+$", arn))
    ])
    error_message = "s3_export_assume_role_arns entries must be IAM role ARNs or ARN patterns of the form arn:aws:iam::<account-id|*>:role/<role-name-or-pattern>."
  }
}

# Resources the caller supplies. They exist before this module runs.

variable "kms_key_arn" {
  type        = string
  description = "ARN of a KMS key the caller supplies. Leave null or \"\" when the root module created the key and passes it in created_resources, or when a standalone call uses the module-created key."
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

variable "existing_brainstore_s3_bucket_arn" {
  type        = string
  description = "ARN of an existing Brainstore S3 bucket. Leave null when the root module created the bucket and passes it in created_resources."
  default     = null
}

variable "existing_brainstore_s3_bucket_kms_key_arn" {
  type        = string
  description = "Optional ARN of the KMS key that encrypts a caller-provided Brainstore bucket. The shared API and Brainstore roles may use it."
  default     = null
}

variable "existing_attachment_s3_bucket_arn" {
  type        = string
  description = "Optional ARN of a caller-provided attachment S3 bucket. The shared API role gets access to the bucket and its objects."
  default     = null
}

variable "existing_attachment_s3_bucket_kms_key_arn" {
  type        = string
  description = "Optional ARN of the KMS key that encrypts the caller-provided attachment bucket."
  default     = null
}

variable "external_attachment_s3_bucket_arns" {
  type        = list(string)
  description = "ARNs of caller-owned S3 buckets that traces link to as external attachments. When non-empty, the shared API role may read their objects."
  default     = []
}

variable "external_attachment_s3_bucket_kms_key_arns" {
  type        = list(string)
  description = "ARNs of the KMS keys that encrypt the external attachment buckets. When non-empty, the shared API role may decrypt with them through S3."
  default     = []
}

variable "existing_quarantine_vpc_id" {
  type        = string
  description = "ID of a caller-provided quarantine VPC. Leave null when the root module created the VPC and passes it in created_resources."
  default     = null
}

variable "use_postgres_connection_override" {
  type        = bool
  description = "Whether the root module's postgres_connection_override is set. The override itself is sensitive, so only this flag comes in. When true, the Postgres URL secret is the override secret, not the module's database URL secret."
  default     = false
}

variable "postgres_connection_override_credentials_secret_arn" {
  type        = string
  description = "The credentials_secret_arn of postgres_connection_override, when it sets one. The ARN isn't sensitive. A customer-managed key on that secret must be kms_key_arn. Used when iam_owner is \"customer\", because that call has no created_resources. Leave null when the override doesn't set one."
  default     = null
}

variable "diagnostics_transcript_log_group_name" {
  description = "Optional existing CloudWatch log group in this account and region for protected SSM and ECS Exec transcripts. The bootstrap owns the group. Null keeps legacy Exec permissions unchanged and grants no transcript delivery."
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
    Exact ARNs of the KMS key, secrets, buckets and quarantine VPC the root module created. An attribute stays null when its resource doesn't exist.
    database_secret_arn is the exception: when postgres_connection_override sets credentials_secret_arn, the root module passes the caller's secret, which it didn't create.
    Every policy that needs one of these waits for all of them, because Terraform tracks the whole object as one value. Keep only resources here that can't depend on any role in this module. Anything that can goes in its own input.
    Only the managed call (iam_owner = "braintrust") passes this. A role's precondition that checks one of these ARNs runs only then. A standalone run (iam_owner = "customer") leaves it empty and scopes by prefix, alias and tag instead.
  EOT
  type = object({
    kms_key_arn                               = optional(string)
    database_secret_arn                       = optional(string)
    database_url_secret_arn                   = optional(string)
    function_tools_secret_arn                 = optional(string)
    redis_url_secret_arn                      = optional(string)
    brainstore_license_key_secret_arn         = optional(string)
    internal_observability_api_key_secret_arn = optional(string)
    brainstore_s3_bucket_arn                  = optional(string)
    code_bundle_s3_bucket_arn                 = optional(string)
    lambda_responses_s3_bucket_arn            = optional(string)
    quarantine_vpc_id                         = optional(string)
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
