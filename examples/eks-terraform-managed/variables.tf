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

variable "kubernetes_version" {
  description = "Kubernetes version for the EKS cluster."
  type        = string
  default     = "1.31"
}

variable "eks_enable_node_ssm" {
  description = "Enable AWS Systems Manager Session Manager on EKS nodes for debugging."
  type        = bool
  default     = false
}

variable "eks_node_group_ami_type" {
  description = "AMI type for the system and services node groups."
  type        = string
  default     = "AL2023_x86_64_STANDARD"
}

variable "eks_brainstore_node_group_ami_type" {
  description = "AMI type for the Brainstore reader and writer node groups."
  type        = string
  default     = "AL2023_ARM_64_STANDARD"
}

variable "eks_system_node_group_instance_type" {
  description = "Instance type for the system node group."
  type        = string
  default     = "t3.medium"
}

variable "eks_system_node_group_desired_size" {
  description = "Desired node count for the system node group."
  type        = number
  default     = 2
}

variable "eks_system_node_group_min_size" {
  description = "Minimum node count for the system node group."
  type        = number
  default     = 2
}

variable "eks_system_node_group_max_size" {
  description = "Maximum node count for the system node group."
  type        = number
  default     = 4
}

variable "eks_system_node_group_disk_size" {
  description = "Root EBS volume size in GB for the system node group."
  type        = number
  default     = 50
}

variable "eks_services_node_group_instance_type" {
  description = "Instance type for the services node group."
  type        = string
  default     = "r6i.2xlarge"
}

variable "eks_services_node_group_desired_size" {
  description = "Desired node count for the services node group."
  type        = number
  default     = 2
}

variable "eks_services_node_group_min_size" {
  description = "Minimum node count for the services node group."
  type        = number
  default     = 2
}

variable "eks_services_node_group_max_size" {
  description = "Maximum node count for the services node group."
  type        = number
  default     = 10
}

variable "eks_services_node_group_disk_size" {
  description = "Root EBS volume size in GB for the services node group."
  type        = number
  default     = 100
}

variable "eks_brainstore_reader_node_group_instance_type" {
  description = "Instance type for the Brainstore reader node group. Must have local NVMe storage."
  type        = string
  default     = "c8gd.8xlarge"
}

variable "eks_brainstore_reader_node_group_desired_size" {
  description = "Desired node count for the Brainstore reader node group."
  type        = number
  default     = 2
}

variable "eks_brainstore_reader_node_group_min_size" {
  description = "Minimum node count for the Brainstore reader node group."
  type        = number
  default     = 2
}

variable "eks_brainstore_reader_node_group_max_size" {
  description = "Maximum node count for the Brainstore reader node group."
  type        = number
  default     = 10
}

variable "eks_brainstore_writer_node_group_instance_type" {
  description = "Instance type for the Brainstore writer node group. Must have local NVMe storage."
  type        = string
  default     = "c8gd.16xlarge"
}

variable "eks_brainstore_writer_node_group_desired_size" {
  description = "Desired node count for the Brainstore writer node group."
  type        = number
  default     = 1
}

variable "eks_brainstore_writer_node_group_min_size" {
  description = "Minimum node count for the Brainstore writer node group."
  type        = number
  default     = 1
}

variable "eks_brainstore_writer_node_group_max_size" {
  description = "Maximum node count for the Brainstore writer node group."
  type        = number
  default     = 5
}

variable "eks_enable_services_spot_node_group" {
  description = "Enable an additional spot-backed services node group for burst capacity."
  type        = bool
  default     = false
}

variable "eks_services_spot_node_group_instance_types" {
  description = "Instance types for the services spot node group."
  type        = list(string)
  default     = ["r6i.2xlarge", "r5.2xlarge", "r6a.2xlarge"]
}

variable "eks_services_spot_node_group_min_size" {
  description = "Minimum node count for the services spot node group."
  type        = number
  default     = 0
}

variable "eks_services_spot_node_group_max_size" {
  description = "Maximum node count for the services spot node group."
  type        = number
  default     = 9
}

variable "eks_enable_brainstore_spot_node_group" {
  description = "Enable an additional spot-backed Brainstore reader node group for burst capacity."
  type        = bool
  default     = false
}

variable "eks_brainstore_spot_node_group_instance_types" {
  description = "Instance types for the Brainstore reader spot node group. Must have local NVMe storage."
  type        = list(string)
  default     = ["c8gd.8xlarge", "c8gd.12xlarge", "c6gd.8xlarge"]
}

variable "eks_brainstore_spot_node_group_min_size" {
  description = "Minimum node count for the Brainstore reader spot node group."
  type        = number
  default     = 0
}

variable "eks_brainstore_spot_node_group_max_size" {
  description = "Maximum node count for the Brainstore reader spot node group."
  type        = number
  default     = 9
}

variable "eks_enable_brainstore_writer_spot_node_group" {
  description = "Enable an additional spot-backed Brainstore writer node group for burst capacity."
  type        = bool
  default     = false
}

variable "eks_brainstore_writer_spot_node_group_instance_types" {
  description = "Instance types for the Brainstore writer spot node group. Must have local NVMe storage."
  type        = list(string)
  default     = ["c8gd.16xlarge", "c7gd.16xlarge", "c6gd.16xlarge"]
}

variable "eks_brainstore_writer_spot_node_group_min_size" {
  description = "Minimum node count for the Brainstore writer spot node group."
  type        = number
  default     = 0
}

variable "eks_brainstore_writer_spot_node_group_max_size" {
  description = "Maximum node count for the Brainstore writer spot node group."
  type        = number
  default     = 9
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
