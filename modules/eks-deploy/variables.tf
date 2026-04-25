## Context

variable "deployment_name" {
  type        = string
  description = "Name of this deployment. Used in tags and resource naming."
}

variable "braintrust_org_name" {
  type        = string
  description = "Braintrust org name (becomes global.orgName in the chart)."
}

variable "namespace" {
  type        = string
  description = "Kubernetes namespace for Braintrust workloads. Created by this submodule."
}

## Cluster (outputs from eks-cluster)

variable "cluster_name" {
  type        = string
  description = "EKS cluster name (used for Pod Identity associations)."
}

variable "node_iam_role_name" {
  type        = string
  description = "Auto Mode node IAM role name (the NodeClass `spec.role` field expects a role name, not an ARN)."
}

variable "nlb_security_group_id" {
  type        = string
  description = "Security group attached to the pre-created NLB (annotated on the api Service)."
}

variable "nlb_name" {
  type        = string
  description = "Name of the pre-created NLB (annotated on the api Service so the LB Controller adopts it)."
}

## IAM role ARNs (outputs from services_common)

variable "api_handler_role_arn" {
  type        = string
  description = "ARN of the API handler IAM role (consumed via api.serviceAccount.awsRoleArn and used for the api Pod Identity association)."
}

variable "brainstore_iam_role_arn" {
  type        = string
  description = "ARN of the Brainstore IAM role (consumed via brainstore.serviceAccount.awsRoleArn and used for the brainstore Pod Identity association)."
}

## Service account names (match chart defaults)

variable "api_service_account_name" {
  type        = string
  default     = "braintrust-api"
  description = "Kubernetes service account name the API pods use (matches chart default)."
}

variable "brainstore_service_account_name" {
  type        = string
  default     = "brainstore"
  description = "Kubernetes service account name the Brainstore pods use (matches chart default)."
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
  sensitive   = true
  description = "Postgres password."
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
  sensitive   = true
  description = "Brainstore license key."
}

## Feature flags passed through to the chart

variable "brainstore_wal_footer_version" {
  type        = string
  description = "WAL footer version (top-level chart value)."
}

variable "skip_pg_for_brainstore_objects" {
  type        = string
  description = "Controls which object types bypass PostgreSQL (top-level chart value)."
}

## Brainstore NodePool (NVMe-constrained)

variable "brainstore_nodepool_instance_families" {
  type        = list(string)
  description = "EC2 instance families the Brainstore NodePool will pick from (must be NVMe-backed, e.g. c8gd)."
}

## Helm chart

variable "helm_chart_version" {
  type        = string
  description = "Version of the Braintrust Helm chart (oci://public.ecr.aws/braintrust/helm)."
}

variable "helm_values_file" {
  type        = string
  default     = null
  description = "Path to a YAML file with Helm values overrides, merged in after the module's rendered defaults (later-wins per Helm's standard merge). Use an absolute path or a path anchored at the caller's module with `$${path.module}/values.yaml`. Anything the chart exposes is fair game — replicas, resources, annotations, nodeSelector, probes, image pins. See the Braintrust Helm chart's `values.yaml` for the schema. Leave null to accept chart defaults."
}

## Destroy choreography

variable "prepare_for_destroy" {
  type        = bool
  default     = false
  description = "Pre-flight before terraform destroy: zero the deregistration_delay on the LBC-managed TargetGroup(s) for this deployment and patch the matching annotation on the api Service. Prevents the LB Controller's finalizer from hanging helm_release.braintrust's destroy and lets the controller finish its own TG cleanup. Apply with this true, then destroy."
}
