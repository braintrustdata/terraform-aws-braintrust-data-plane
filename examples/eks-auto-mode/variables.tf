variable "deployment_name" {
  description = "Name of this Braintrust deployment. Lowercase letters, numbers, and hyphens only. Do not change after initial deployment."
  type        = string
  default     = "braintrust"
}

variable "braintrust_org_name" {
  description = "Your organization name in Braintrust."
  type        = string
}

variable "brainstore_license_key" {
  description = "Brainstore license key from the Braintrust UI."
  type        = string
  sensitive   = true
}

variable "custom_tags" {
  description = "Additional AWS tags to apply to resources created by this example."
  type        = map(string)
  default     = {}
}

variable "custom_domain" {
  description = "Optional custom API hostname for CloudFront, e.g. braintrust.example.com. Leave null to use the CloudFront domain."
  type        = string
  default     = null
}

variable "custom_certificate_arn" {
  description = "ACM certificate ARN in us-east-1 for custom_domain. Required when custom_domain is set."
  type        = string
  default     = null
}

variable "waf_acl_id" {
  description = "Optional WAF Web ACL ARN/ID to attach to the CloudFront distribution."
  type        = string
  default     = null
}

variable "cloudfront_price_class" {
  description = "CloudFront price class for the Braintrust API edge."
  type        = string
  default     = "PriceClass_100"
}

variable "eks_namespace" {
  description = "Kubernetes namespace where Braintrust workloads are deployed."
  type        = string
  default     = "braintrust"
}

variable "eks_helm_chart_version" {
  description = "Version of the Braintrust Helm chart to deploy."
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version for the EKS cluster. EKS Auto Mode requires >= 1.29."
  type        = string
  default     = "1.31"
}

variable "eks_enable_public_access" {
  description = "Whether the EKS public API server endpoint is enabled. Set false only when Terraform runs from the VPC or a connected network."
  type        = bool
  default     = true
}

variable "eks_public_access_cidrs" {
  description = "CIDR blocks allowed to reach the EKS public API server endpoint. Defaults to 0.0.0.0/0 for compatibility; restrict this to explicit operator or CI egress CIDRs for production."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "eks_access_entries" {
  description = "Additional EKS access entries for human operators or CI roles."
  type = map(object({
    principal_arn     = string
    type              = optional(string, "STANDARD")
    kubernetes_groups = optional(list(string))
    user_name         = optional(string)
    policy_associations = optional(map(object({
      policy_arn = string
      access_scope = object({
        type       = string
        namespaces = optional(list(string), [])
      })
    })), {})
  }))
  default = {}

  validation {
    condition = alltrue(flatten([
      for _, entry in var.eks_access_entries : [
        for _, policy_association in entry.policy_associations : (
          contains(["cluster", "namespace"], policy_association.access_scope.type) &&
          (
            (
              policy_association.access_scope.type == "cluster" &&
              length(policy_association.access_scope.namespaces) == 0
            ) ||
            (
              policy_association.access_scope.type == "namespace" &&
              length(policy_association.access_scope.namespaces) > 0
            )
          )
        )
      ]
    ]))
    error_message = "Each EKS access policy association must use access_scope.type of cluster with no namespaces, or namespace with at least one namespace."
  }
}

variable "postgres_instance_type" {
  description = "RDS instance type."
  type        = string
  default     = "db.r8g.2xlarge"
}

variable "postgres_storage_size" {
  description = "Initial RDS allocated storage in GB."
  type        = number
  default     = 1000
}

variable "postgres_max_storage_size" {
  description = "Maximum RDS storage autoscaling limit in GB."
  type        = number
  default     = 10000
}

variable "postgres_storage_iops" {
  description = "Provisioned gp3 IOPS for RDS."
  type        = number
  default     = 15000
}

variable "postgres_storage_throughput" {
  description = "Provisioned gp3 throughput for RDS in MiB/s."
  type        = number
  default     = 500
}

variable "redis_instance_type" {
  description = "ElastiCache node type for Redis."
  type        = string
  default     = "cache.t4g.medium"
}

variable "eks_brainstore_instance_families" {
  description = "NVMe-backed Graviton instance families for Brainstore Karpenter NodePools. Must support local NVMe storage (c7gd, c8gd)."
  type        = list(string)
  default     = ["c7gd", "c8gd"]
}

variable "eks_brainstore_reader_instance_sizes" {
  description = "EC2 instance sizes allowed for the Brainstore reader and fast-reader Auto Mode NodePool."
  type        = list(string)
  default     = ["4xlarge"]
}

variable "eks_brainstore_writer_instance_sizes" {
  description = "EC2 instance sizes allowed for the Brainstore writer Auto Mode NodePool."
  type        = list(string)
  default     = ["8xlarge"]
}

variable "brainstore_wal_footer_version" {
  description = "WAL footer version for Brainstore. Only change when instructed by Braintrust."
  type        = string
  default     = "v3"
}

variable "skip_pg_for_brainstore_objects" {
  description = "Controls which object types bypass PostgreSQL. This is a one-way migration setting."
  type        = string
  default     = "all"
}

variable "eks_api_helm" {
  type = object({
    replicas = optional(number)
    resources = optional(object({
      requests = object({ cpu = string, memory = string })
      limits   = object({ cpu = string, memory = string })
    }))
  })
  default     = {}
  description = "Optional API replica/resource overrides for the Braintrust Helm chart."
}

variable "eks_brainstore_reader_helm" {
  type = object({
    replicas = optional(number)
    resources = optional(object({
      requests = object({ cpu = string, memory = string })
      limits   = object({ cpu = string, memory = string })
    }))
  })
  default = {
    replicas = 1
    resources = {
      requests = {
        cpu    = "14"
        memory = "26Gi"
      }
      limits = {
        cpu    = "14"
        memory = "26Gi"
      }
    }
  }
  description = "Brainstore reader overrides for the Auto Mode example. Defaults leave allocatable headroom on the example's 4xlarge reader nodes; override if you need different sizing."
}

variable "eks_brainstore_fastreader_helm" {
  type = object({
    replicas = optional(number)
    resources = optional(object({
      requests = object({ cpu = string, memory = string })
      limits   = object({ cpu = string, memory = string })
    }))
  })
  default = {
    replicas = 1
    resources = {
      requests = {
        cpu    = "14"
        memory = "26Gi"
      }
      limits = {
        cpu    = "14"
        memory = "26Gi"
      }
    }
  }
  description = "Brainstore fast-reader overrides for the Auto Mode example. Defaults leave allocatable headroom on the example's 4xlarge reader nodes; override if you need different sizing."
}

variable "eks_brainstore_writer_helm" {
  type = object({
    replicas = optional(number)
    resources = optional(object({
      requests = object({ cpu = string, memory = string })
      limits   = object({ cpu = string, memory = string })
    }))
  })
  default = {
    replicas = 1
    resources = {
      requests = {
        cpu    = "30"
        memory = "58Gi"
      }
      limits = {
        cpu    = "30"
        memory = "58Gi"
      }
    }
  }
  description = "Brainstore writer overrides for the Auto Mode example. Defaults leave allocatable headroom on the example's 8xlarge writer nodes; override if you need different sizing."
}

variable "eks_helm_chart_extra_values" {
  description = "Raw YAML Helm override appended after the generated EKS values."
  type        = string
  default     = ""
}

variable "prepare_for_destroy" {
  description = "Apply with true before terraform destroy to shorten NLB target deregistration and reduce LB controller finalizer stalls."
  type        = bool
  default     = false
}
