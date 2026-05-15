# tflint-ignore-file: terraform_module_pinned_source

# Opinionated Terraform-managed EKS example:
# - creates the Braintrust AWS data plane primitives
# - creates an EKS cluster with Terraform-managed node groups
# - leaves Braintrust Helm installation to a follow-up manual step
# - defaults to bring-your-own ingress, with an optional toggle for bundled CloudFront + private NLB

module "braintrust" {
  source = "github.com/braintrustdata/terraform-braintrust-data-plane"

  deployment_name        = var.deployment_name
  braintrust_org_name    = var.braintrust_org_name
  brainstore_license_key = var.brainstore_license_key
  custom_tags            = var.custom_tags

  use_deployment_mode_eks = true
  create_eks_cluster      = true
  enable_quarantine_vpc   = false

  eks_use_auto_mode                 = false
  eks_enable_cloudfront_nlb_ingress = var.eks_enable_cloudfront_nlb_ingress
  eks_enable_private_access         = true
  eks_enable_public_access          = var.eks_enable_public_access
  eks_public_access_cidrs           = var.eks_public_access_cidrs
  eks_access_entries                = var.eks_access_entries

  custom_domain          = var.custom_domain
  custom_certificate_arn = var.custom_certificate_arn
  waf_acl_id             = var.waf_acl_id
  cloudfront_price_class = var.cloudfront_price_class

  eks_namespace = var.eks_namespace

  kubernetes_version                 = var.kubernetes_version
  eks_enable_node_ssm                = var.eks_enable_node_ssm
  eks_node_group_ami_type            = var.eks_node_group_ami_type
  eks_brainstore_node_group_ami_type = var.eks_brainstore_node_group_ami_type

  eks_system_node_group_instance_type = var.eks_system_node_group_instance_type
  eks_system_node_group_desired_size  = var.eks_system_node_group_desired_size
  eks_system_node_group_min_size      = var.eks_system_node_group_min_size
  eks_system_node_group_max_size      = var.eks_system_node_group_max_size
  eks_system_node_group_disk_size     = var.eks_system_node_group_disk_size

  eks_services_node_group_instance_type = var.eks_services_node_group_instance_type
  eks_services_node_group_desired_size  = var.eks_services_node_group_desired_size
  eks_services_node_group_min_size      = var.eks_services_node_group_min_size
  eks_services_node_group_max_size      = var.eks_services_node_group_max_size
  eks_services_node_group_disk_size     = var.eks_services_node_group_disk_size

  eks_brainstore_reader_node_group_instance_type = var.eks_brainstore_reader_node_group_instance_type
  eks_brainstore_reader_node_group_desired_size  = var.eks_brainstore_reader_node_group_desired_size
  eks_brainstore_reader_node_group_min_size      = var.eks_brainstore_reader_node_group_min_size
  eks_brainstore_reader_node_group_max_size      = var.eks_brainstore_reader_node_group_max_size

  eks_brainstore_writer_node_group_instance_type = var.eks_brainstore_writer_node_group_instance_type
  eks_brainstore_writer_node_group_desired_size  = var.eks_brainstore_writer_node_group_desired_size
  eks_brainstore_writer_node_group_min_size      = var.eks_brainstore_writer_node_group_min_size
  eks_brainstore_writer_node_group_max_size      = var.eks_brainstore_writer_node_group_max_size

  eks_enable_services_spot_node_group         = var.eks_enable_services_spot_node_group
  eks_services_spot_node_group_instance_types = var.eks_services_spot_node_group_instance_types
  eks_services_spot_node_group_min_size       = var.eks_services_spot_node_group_min_size
  eks_services_spot_node_group_max_size       = var.eks_services_spot_node_group_max_size

  eks_enable_brainstore_spot_node_group         = var.eks_enable_brainstore_spot_node_group
  eks_brainstore_spot_node_group_instance_types = var.eks_brainstore_spot_node_group_instance_types
  eks_brainstore_spot_node_group_min_size       = var.eks_brainstore_spot_node_group_min_size
  eks_brainstore_spot_node_group_max_size       = var.eks_brainstore_spot_node_group_max_size

  eks_enable_brainstore_writer_spot_node_group         = var.eks_enable_brainstore_writer_spot_node_group
  eks_brainstore_writer_spot_node_group_instance_types = var.eks_brainstore_writer_spot_node_group_instance_types
  eks_brainstore_writer_spot_node_group_min_size       = var.eks_brainstore_writer_spot_node_group_min_size
  eks_brainstore_writer_spot_node_group_max_size       = var.eks_brainstore_writer_spot_node_group_max_size

  postgres_instance_type              = var.postgres_instance_type
  postgres_storage_size               = var.postgres_storage_size
  postgres_max_storage_size           = var.postgres_max_storage_size
  postgres_storage_type               = "gp3"
  postgres_storage_iops               = var.postgres_storage_iops
  postgres_storage_throughput         = var.postgres_storage_throughput
  postgres_version                    = "15"
  postgres_auto_minor_version_upgrade = true

  redis_instance_type = var.redis_instance_type
  redis_version       = "7.0"
}
