#----------------------------------------------------------------------------------------------
# Common
#----------------------------------------------------------------------------------------------
variable "deployment_name" {
  description = "Name of the deployment. Used to prefix resource names."
  type        = string
}

variable "custom_tags" {
  type        = map(string)
  description = "Additional tags to apply to all resources"
  default     = {}
}

variable "permissions_boundary_arn" {
  type        = string
  description = "IAM permissions boundary ARN applied to IAM roles created by this module."
  default     = null
}

#----------------------------------------------------------------------------------------------
# EKS Cluster
#----------------------------------------------------------------------------------------------
variable "kubernetes_version" {
  type        = string
  description = "Kubernetes version for the EKS cluster"
  default     = "1.31"
}

variable "subnet_ids" {
  type        = list(string)
  description = "List of subnet IDs for the EKS cluster and node groups. Must be in at least two different availability zones."
}

variable "vpc_id" {
  type        = string
  description = "VPC ID where the EKS cluster, internal NLB, and security groups are created."
}

variable "aws_load_balancer_controller_service_account" {
  type        = string
  description = "Kubernetes service account name used by the AWS Load Balancer Controller."
  default     = "aws-load-balancer-controller"
}

variable "braintrust_namespace" {
  type        = string
  description = "Kubernetes namespace used by Braintrust workloads."
}

variable "braintrust_api_service_account" {
  type        = string
  description = "Kubernetes service account name for the Braintrust API pods."
}

variable "brainstore_service_account" {
  type        = string
  description = "Kubernetes service account name for Brainstore pods."
}

variable "braintrust_api_role_arn" {
  type        = string
  description = "IAM role ARN for the Braintrust API Pod Identity association."
}

variable "brainstore_role_arn" {
  type        = string
  description = "IAM role ARN for the Brainstore Pod Identity association."
}

variable "enable_private_access" {
  type        = bool
  description = "Whether the Amazon EKS private API server endpoint is enabled"
  default     = true
}

variable "enable_public_access" {
  type        = bool
  description = "Whether the Amazon EKS public API server endpoint is enabled"
  default     = true
}

variable "public_access_cidrs" {
  type        = list(string)
  description = "List of CIDR blocks that can access the Amazon EKS public API server endpoint"
  default     = ["0.0.0.0/0"]
}

variable "eks_access_entries" {
  description = "Additional EKS access entries to create for human or CI access. The cluster creator still receives bootstrap admin permissions."
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

variable "additional_security_group_ids" {
  type        = list(string)
  description = "Additional security group IDs to attach to the EKS cluster"
  default     = []
}

variable "kms_key_arn" {
  type        = string
  description = "ARN of the KMS key to use for encrypting Kubernetes secrets"
}

variable "cluster_log_types" {
  type        = list(string)
  description = "List of control plane logging types to enable. Valid values: api, audit, authenticator, controllerManager, scheduler"
  default     = ["api", "audit", "authenticator"]
}

variable "cluster_log_retention_days" {
  type        = number
  description = "Number of days to retain EKS control plane logs in CloudWatch. Set to 0 for indefinite retention."
  default     = 90
  validation {
    condition = contains([
      0, 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180,
      365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653
    ], var.cluster_log_retention_days)
    error_message = "cluster_log_retention_days must be 0 or a valid CloudWatch Logs retention value."
  }
}

#----------------------------------------------------------------------------------------------
# Node Groups
#----------------------------------------------------------------------------------------------
variable "enable_node_ssm" {
  type        = bool
  description = "Enable AWS Systems Manager Session Manager for node debugging"
  default     = false
}

variable "node_group_ami_type" {
  type        = string
  description = "AMI type for the system and services node groups. Use AL2023_ARM_64_STANDARD if those groups also run Graviton instances."
  default     = "AL2023_x86_64_STANDARD"
  validation {
    condition     = contains(["AL2023_x86_64_STANDARD", "AL2023_ARM_64_STANDARD", "AL2_x86_64", "AL2_ARM_64"], var.node_group_ami_type)
    error_message = "Must be one of: AL2023_x86_64_STANDARD, AL2023_ARM_64_STANDARD, AL2_x86_64, AL2_ARM_64."
  }
}

variable "brainstore_node_group_ami_type" {
  type        = string
  description = "AMI type for the brainstore node groups. Defaults to AL2023_ARM_64_STANDARD because c8gd (Graviton4 NVMe) instances are the recommended default for Brainstore."
  default     = "AL2023_ARM_64_STANDARD"
  validation {
    condition     = contains(["AL2023_x86_64_STANDARD", "AL2023_ARM_64_STANDARD", "AL2_x86_64", "AL2_ARM_64"], var.brainstore_node_group_ami_type)
    error_message = "Must be one of: AL2023_x86_64_STANDARD, AL2023_ARM_64_STANDARD, AL2_x86_64, AL2_ARM_64."
  }
}

# System Node Group
variable "system_node_group_instance_type" {
  type        = string
  description = "Instance type for the system node group"
  default     = "t3.medium"
}

variable "system_node_group_desired_size" {
  type        = number
  description = "Desired number of nodes in the system node group"
  default     = 2
}

variable "system_node_group_min_size" {
  type        = number
  description = "Minimum number of nodes in the system node group"
  default     = 2
}

variable "system_node_group_max_size" {
  type        = number
  description = "Maximum number of nodes in the system node group"
  default     = 4
}

variable "system_node_group_disk_size" {
  type        = number
  description = "Root EBS volume size in GB for system node group instances"
  default     = 50
}

# Services Node Group
variable "services_node_group_instance_type" {
  type        = string
  description = "Instance type for the services node group"
  default     = "r6i.2xlarge"
}

variable "services_node_group_desired_size" {
  type        = number
  description = "Desired number of nodes in the services node group"
  default     = 2
}

variable "services_node_group_min_size" {
  type        = number
  description = "Minimum number of nodes in the services node group"
  default     = 2
}

variable "services_node_group_max_size" {
  type        = number
  description = "Maximum number of nodes in the services node group"
  default     = 10
}

variable "services_node_group_disk_size" {
  type        = number
  description = "Root EBS volume size in GB for services node group instances"
  default     = 100
}

# Brainstore Reader Node Group (reader + fast-reader pods)
variable "brainstore_reader_node_group_instance_type" {
  type        = string
  description = "Instance type for the brainstore reader node group. Must be an instance with local NVMe storage. c8gd (Graviton4) instances are the recommended default."
  default     = "c8gd.8xlarge"
}

variable "brainstore_reader_node_group_desired_size" {
  type        = number
  description = "Desired number of nodes in the brainstore reader node group"
  default     = 2
}

variable "brainstore_reader_node_group_min_size" {
  type        = number
  description = "Minimum number of nodes in the brainstore reader node group"
  default     = 2
}

variable "brainstore_reader_node_group_max_size" {
  type        = number
  description = "Maximum number of nodes in the brainstore reader node group"
  default     = 10
}

# Brainstore Writer Node Group
variable "brainstore_writer_node_group_instance_type" {
  type        = string
  description = "Instance type for the brainstore writer node group. Must be an instance with local NVMe storage. Defaults to c8gd.16xlarge (2× the vCPU/memory of the reader default)."
  default     = "c8gd.16xlarge"
}

variable "brainstore_writer_node_group_desired_size" {
  type        = number
  description = "Desired number of nodes in the brainstore writer node group"
  default     = 1
}

variable "brainstore_writer_node_group_min_size" {
  type        = number
  description = "Minimum number of nodes in the brainstore writer node group"
  default     = 1
}

variable "brainstore_writer_node_group_max_size" {
  type        = number
  description = "Maximum number of nodes in the brainstore writer node group"
  default     = 5
}

# Spot Node Groups
# When enabled, a spot node group is created alongside the on-demand baseline. The on-demand
# group provides one stable node at all times; the spot group adds optional extra capacity for
# non-Auto-Mode deployments.
variable "enable_services_spot_node_group" {
  type        = bool
  description = "Add a spot node group for services burst capacity. The on-demand node group remains the stable baseline; spot provides optional extra capacity for non-Auto-Mode deployments."
  default     = false
}

variable "services_spot_node_group_instance_types" {
  type        = list(string)
  description = "Instance types for the services spot node group. Providing multiple similar types improves spot availability. All listed types should have the same CPU and memory ratio."
  default     = ["r6i.2xlarge", "r5.2xlarge", "r6a.2xlarge"]
}

variable "services_spot_node_group_min_size" {
  type        = number
  description = "Minimum number of nodes in the services spot node group. Defaults to 0 so the group scales to zero when idle."
  default     = 0
}

variable "services_spot_node_group_max_size" {
  type        = number
  description = "Maximum number of nodes in the services spot node group."
  default     = 9
}

variable "enable_brainstore_spot_node_group" {
  type        = bool
  description = "Add a spot node group for brainstore burst capacity. Note: spot interruptions cause cache loss; pods rehydrate from S3 on restart."
  default     = false
}

variable "brainstore_spot_node_group_instance_types" {
  type        = list(string)
  description = "Instance types for the brainstore spot node group. Must be NVMe-backed Graviton instances so the local NVMe mount script runs correctly. All listed types must be ARM64-compatible."
  default     = ["c8gd.8xlarge", "c8gd.12xlarge", "c6gd.8xlarge"]
}

variable "brainstore_spot_node_group_min_size" {
  type        = number
  description = "Minimum number of nodes in the brainstore spot node group. Defaults to 0 so the group scales to zero when idle."
  default     = 0
}

variable "brainstore_spot_node_group_max_size" {
  type        = number
  description = "Maximum number of nodes in the brainstore spot node group."
  default     = 9
}

variable "enable_brainstore_writer_spot_node_group" {
  type        = bool
  description = "Add a spot node group for brainstore writer burst capacity. Spot interruptions cause cache loss; pods rehydrate from S3 on restart."
  default     = false
}

variable "brainstore_writer_spot_node_group_instance_types" {
  type        = list(string)
  description = "Instance types for the brainstore writer spot node group. Must be NVMe-backed Graviton instances with 2× the vCPU/memory of reader instances."
  default     = ["c8gd.16xlarge", "c7gd.16xlarge", "c6gd.16xlarge"]
}

variable "brainstore_writer_spot_node_group_min_size" {
  type        = number
  description = "Minimum number of nodes in the brainstore writer spot node group."
  default     = 0
}

variable "brainstore_writer_spot_node_group_max_size" {
  type        = number
  description = "Maximum number of nodes in the brainstore writer spot node group."
  default     = 9
}

#----------------------------------------------------------------------------------------------
# EKS Addons
#----------------------------------------------------------------------------------------------
variable "vpc_cni_addon_version" {
  type        = string
  description = "Version of the VPC CNI addon. If not specified, uses the default version for the cluster."
  default     = null
}

variable "kube_proxy_addon_version" {
  type        = string
  description = "Version of the kube-proxy addon. If not specified, uses the default version for the cluster."
  default     = null
}

variable "coredns_addon_version" {
  type        = string
  description = "Version of the CoreDNS addon. If not specified, uses the default version for the cluster."
  default     = null
}


variable "pod_identity_addon_version" {
  type        = string
  description = "Version of the EKS Pod Identity agent addon. If not specified, uses the default version for the cluster."
  default     = null
}

#----------------------------------------------------------------------------------------------
# Ingress Edge
#----------------------------------------------------------------------------------------------
variable "enable_cloudfront_nlb_ingress" {
  type        = bool
  description = "When true, creates the module-managed CloudFront + private NLB ingress stack for the EKS deployment. Set false if you want the EKS cluster without the bundled ingress so you can bring your own ingress/controller setup."
  default     = true
}

variable "cloudfront_price_class" {
  type        = string
  description = "CloudFront price class for the EKS API edge."
  default     = "PriceClass_100"
}

variable "custom_domain" {
  type        = string
  description = "Optional custom domain name for the CloudFront distribution."
  default     = null
}

variable "custom_certificate_arn" {
  type        = string
  description = "Optional ACM certificate ARN in us-east-1 for the CloudFront custom domain."
  default     = null
}

variable "waf_acl_id" {
  type        = string
  description = "Optional WAF Web ACL ID/ARN to associate with the CloudFront distribution."
  default     = null
}

variable "use_global_ai_proxy" {
  type        = bool
  description = "Whether to route proxy, eval, and function edge paths to the global Cloudflare proxy instead of the EKS API origin."
  default     = false
}

#----------------------------------------------------------------------------------------------
# EKS Auto Mode
#----------------------------------------------------------------------------------------------
variable "use_eks_auto_mode" {
  type        = bool
  description = "Enable EKS Auto Mode. When true, EKS manages compute (system and services nodes), load balancing, and block storage automatically. System and services managed node groups are not created — EKS Auto Mode provisions them via built-in node pools. Brainstore capacity is supplied separately through custom Auto Mode NodeClass and NodePool resources created by the eks-deploy module."
  default     = true
}
