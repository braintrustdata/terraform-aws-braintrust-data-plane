## Context

variable "deployment_name" {
  type        = string
  description = "Name of this deployment. Used in tags and resource naming."
}

variable "custom_tags" {
  type        = map(string)
  description = "Custom tags applied to created resources."
  default     = {}
}

variable "braintrust_org_name" {
  type        = string
  description = "Braintrust org name (becomes global.orgName in the Helm chart)."
}

variable "namespace" {
  type        = string
  description = "Kubernetes namespace for Braintrust workloads. Created by this submodule."
}

## Cluster (outputs from eks-cluster)

variable "cluster_name" {
  type        = string
  description = "EKS cluster name (used by the Load Balancer Controller Helm release)."
}

variable "vpc_id" {
  type        = string
  description = "VPC ID (used by the Load Balancer Controller Helm release)."
}

variable "lb_controller_role_arn" {
  type        = string
  description = "IAM role ARN for the AWS Load Balancer Controller service account (IRSA)."
}

variable "nlb_security_group_id" {
  type        = string
  description = "Security group ID attached to the pre-created NLB (annotated on the API service)."
}

variable "nlb_name" {
  type        = string
  description = "Name of the pre-created NLB (annotated on the API service so the Load Balancer Controller adopts it)."
}

## IAM role ARNs (outputs from services_common)

variable "api_handler_role_arn" {
  type        = string
  description = "ARN of the API handler IAM role. Consumed by the chart via api.serviceAccount.awsRoleArn for IRSA."
}

variable "brainstore_iam_role_arn" {
  type        = string
  description = "ARN of the Brainstore IAM role. Consumed by the chart via brainstore.serviceAccount.awsRoleArn for IRSA."
}

## Storage

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

## Database + Redis

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

## Feature flags passed through to the chart

variable "brainstore_wal_footer_version" {
  type        = string
  description = "WAL footer version passed to the chart (top-level value)."
}

variable "skip_pg_for_brainstore_objects" {
  type        = string
  description = "Controls which object types bypass PostgreSQL (top-level chart value)."
}

## Helm chart

variable "helm_chart_version" {
  type        = string
  description = "Version of the Braintrust Helm chart (oci://public.ecr.aws/braintrust/helm)."
}

## Structured per-component Helm overrides
##
## Any field left unset falls back to the chart's default. If `resources` is
## set, both `requests` and `limits` must be provided.

variable "api_helm" {
  type = object({
    replicas = optional(number)
    resources = optional(object({
      requests = object({ cpu = string, memory = string })
      limits   = object({ cpu = string, memory = string })
    }))
  })
  default     = {}
  description = "Override replicas and/or resources for the api component."
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
  description = "Override replicas and/or resources for the brainstore reader."
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
  description = "Override replicas and/or resources for the brainstore fast reader."
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
  description = "Override replicas and/or resources for the brainstore writer."
}

variable "helm_chart_extra_values" {
  type        = string
  default     = ""
  description = "Escape-hatch YAML appended to the chart's values list; wins over template and structured overrides."
}
