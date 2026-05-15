variable "deployment_name" {
  type        = string
  description = "Name of this deployment. Used in resource naming and tags."
}

variable "custom_tags" {
  type        = map(string)
  description = "Custom tags applied to created resources."
  default     = {}
}

variable "braintrust_org_name" {
  type        = string
  description = "Braintrust org name. This becomes global.orgName in the Helm chart."
}

variable "namespace" {
  type        = string
  description = "Kubernetes namespace for Braintrust workloads. Created by this module."
}

variable "cluster_name" {
  type        = string
  description = "EKS cluster name."
}

variable "vpc_id" {
  type        = string
  description = "VPC ID used by the AWS Load Balancer Controller Helm release."
}

variable "nlb_security_group_id" {
  type        = string
  description = "Security group ID attached to the pre-created internal NLB."
}

variable "nlb_name" {
  type        = string
  description = "Name of the pre-created internal NLB for the Braintrust API service to adopt."
}

variable "api_handler_role_arn" {
  type        = string
  description = "IAM role ARN consumed by the Braintrust API service account."
}

variable "api_service_account_name" {
  type        = string
  description = "Kubernetes service account name used by Braintrust API pods."
  default     = "braintrust-api"
}

variable "brainstore_iam_role_arn" {
  type        = string
  description = "IAM role ARN consumed by the Brainstore service account."
}

variable "brainstore_service_account_name" {
  type        = string
  description = "Kubernetes service account name used by Brainstore pods."
  default     = "brainstore"
}

variable "brainstore_bucket_name" {
  type        = string
  description = "S3 bucket name for Brainstore data."
}

variable "response_bucket_name" {
  type        = string
  description = "S3 bucket name for API responses."
}

variable "code_bundle_bucket_name" {
  type        = string
  description = "S3 bucket name for code bundles."
}

variable "postgres_host" {
  type        = string
  description = "Postgres host."
}

variable "postgres_port" {
  type        = number
  description = "Postgres port."
}

variable "postgres_username" {
  type        = string
  description = "Postgres username."
}

variable "postgres_password" {
  type        = string
  description = "Postgres password."
  sensitive   = true
}

variable "redis_host" {
  type        = string
  description = "Redis host."
}

variable "redis_port" {
  type        = number
  description = "Redis port."
}

variable "brainstore_license_key" {
  type        = string
  description = "Brainstore license key."
  sensitive   = true
}

variable "function_secret_key" {
  type        = string
  description = "Function secret key stored in the braintrust-secrets Kubernetes secret."
  sensitive   = true
}

variable "brainstore_wal_footer_version" {
  type        = string
  description = "WAL footer version passed to the chart."
}

variable "skip_pg_for_brainstore_objects" {
  type        = string
  description = "Controls which object types bypass PostgreSQL."
}

variable "helm_chart_version" {
  type        = string
  description = "Version of the Braintrust Helm chart to deploy."
}

variable "manage_braintrust_helm_release" {
  type        = bool
  description = "When true, Terraform manages the Braintrust Helm release. When false, Terraform still prepares the namespace, secret, controller, and optional Auto Mode resources, but expects a manual helm install/upgrade for the Braintrust chart."
  default     = true
}

variable "aws_load_balancer_controller_chart_version" {
  type        = string
  description = "Optional AWS Load Balancer Controller Helm chart version."
  default     = null
}

variable "aws_load_balancer_controller_service_account" {
  type        = string
  description = "Service account name used by the AWS Load Balancer Controller."
  default     = "aws-load-balancer-controller"
}

variable "api_helm" {
  type = object({
    replicas = optional(number)
    resources = optional(object({
      requests = object({ cpu = string, memory = string })
      limits   = object({ cpu = string, memory = string })
    }))
  })
  default     = {}
  description = "Override replicas and/or resources for the API component."
}

variable "brainstore_reader_helm" {
  type = object({
    replicas = optional(number)
    resources = optional(object({
      requests = object({ cpu = string, memory = string })
      limits   = object({ cpu = string, memory = string })
    }))
  })
  default     = {}
  description = "Override replicas and/or resources for the Brainstore reader."
}

variable "brainstore_fastreader_helm" {
  type = object({
    replicas = optional(number)
    resources = optional(object({
      requests = object({ cpu = string, memory = string })
      limits   = object({ cpu = string, memory = string })
    }))
  })
  default     = {}
  description = "Override replicas and/or resources for the Brainstore fast reader."
}

variable "brainstore_writer_helm" {
  type = object({
    replicas = optional(number)
    resources = optional(object({
      requests = object({ cpu = string, memory = string })
      limits   = object({ cpu = string, memory = string })
    }))
  })
  default     = {}
  description = "Override replicas and/or resources for the Brainstore writer."
}

variable "helm_chart_extra_values" {
  type        = string
  description = "Escape-hatch YAML appended to the chart values. Later values win."
  default     = ""
}

variable "prepare_for_destroy" {
  type        = bool
  description = "When true, reduces AWS load balancer target deregistration delay for the Braintrust API Service before destroy."
  default     = false
}

variable "use_auto_mode" {
  type        = bool
  description = "When true, omits node selectors and tolerations for managed node groups that do not exist in Auto Mode, and deploys Brainstore NodeClass/NodePool resources instead."
  default     = false
}

variable "node_role_name" {
  type        = string
  description = "IAM role name for Auto Mode nodes. Required when use_auto_mode is true — used as the NodeClass role reference."
  default     = ""
}

variable "brainstore_instance_families" {
  type        = list(string)
  description = "EC2 instance families for Brainstore NodePools. Must be NVMe-backed Graviton families (c7gd, c8gd)."
  default     = ["c7gd", "c8gd"]
}

variable "brainstore_reader_instance_sizes" {
  type        = list(string)
  description = "EC2 instance sizes allowed for the Brainstore reader and fast-reader Auto Mode NodePool."
  default     = ["4xlarge"]

  validation {
    condition     = length(var.brainstore_reader_instance_sizes) > 0
    error_message = "brainstore_reader_instance_sizes must contain at least one size."
  }
}

variable "brainstore_writer_instance_sizes" {
  type        = list(string)
  description = "EC2 instance sizes allowed for the Brainstore writer Auto Mode NodePool."
  default     = ["8xlarge"]

  validation {
    condition     = length(var.brainstore_writer_instance_sizes) > 0
    error_message = "brainstore_writer_instance_sizes must contain at least one size."
  }
}
