# tflint-ignore-file: terraform_module_pinned_source

# EKS Auto Mode deployment:
# - EKS Auto Mode manages system and API services compute, load balancing, and block storage
#   automatically via its built-in system and general-purpose NodePools.
# - Brainstore reader, fast-reader, and writer pods run on custom Karpenter NodePools backed by
#   NVMe-equipped Graviton instances (c7gd/c8gd). EKS Auto Mode provisions these nodes when the
#   pods are scheduled; no managed node groups are created for Brainstore.
# - The AWS Load Balancer Controller is deployed to adopt the pre-created internal NLB.

module "braintrust" {
  source = "github.com/braintrustdata/terraform-braintrust-data-plane"

  deployment_name        = var.deployment_name
  braintrust_org_name    = var.braintrust_org_name
  brainstore_license_key = var.brainstore_license_key
  custom_tags            = var.custom_tags

  use_deployment_mode_eks = true
  create_eks_cluster      = true
  enable_quarantine_vpc   = false

  # EKS Auto Mode: EKS manages system and API services compute automatically.
  eks_use_auto_mode                 = true
  eks_enable_cloudfront_nlb_ingress = true
  eks_enable_private_access         = true
  eks_enable_public_access          = var.eks_enable_public_access
  eks_public_access_cidrs           = var.eks_public_access_cidrs
  eks_access_entries                = var.eks_access_entries

  custom_domain          = var.custom_domain
  custom_certificate_arn = var.custom_certificate_arn
  waf_acl_id             = var.waf_acl_id
  cloudfront_price_class = var.cloudfront_price_class

  eks_namespace = var.eks_namespace

  kubernetes_version = var.kubernetes_version

  postgres_instance_type      = var.postgres_instance_type
  postgres_storage_size       = var.postgres_storage_size
  postgres_max_storage_size   = var.postgres_max_storage_size
  postgres_storage_type       = "gp3"
  postgres_storage_iops       = var.postgres_storage_iops
  postgres_storage_throughput = var.postgres_storage_throughput

  redis_instance_type = var.redis_instance_type

  brainstore_wal_footer_version  = var.brainstore_wal_footer_version
  skip_pg_for_brainstore_objects = var.skip_pg_for_brainstore_objects
}

module "braintrust_deploy" {
  source = "github.com/braintrustdata/terraform-braintrust-data-plane//modules/eks-deploy"

  providers = {
    kubernetes = kubernetes
    helm       = helm
  }

  deployment_name     = var.deployment_name
  custom_tags         = var.custom_tags
  braintrust_org_name = var.braintrust_org_name
  namespace           = module.braintrust.eks_namespace

  cluster_name          = module.braintrust.eks_cluster_name
  vpc_id                = module.braintrust.main_vpc_id
  nlb_security_group_id = module.braintrust.eks_nlb_security_group_id
  nlb_name              = module.braintrust.eks_nlb_name

  api_handler_role_arn            = module.braintrust.eks_braintrust_api_role_arn
  brainstore_iam_role_arn         = module.braintrust.eks_brainstore_role_arn
  api_service_account_name        = "braintrust-api"
  brainstore_service_account_name = "brainstore"

  brainstore_bucket_name  = module.braintrust.brainstore_s3_bucket_name
  response_bucket_name    = module.braintrust.lambda_responses_s3_bucket_name
  code_bundle_bucket_name = module.braintrust.code_bundle_s3_bucket_name

  postgres_host     = module.braintrust.postgres_database_address
  postgres_port     = module.braintrust.postgres_database_port
  postgres_username = module.braintrust.postgres_database_username
  postgres_password = module.braintrust.postgres_database_password
  redis_host        = module.braintrust.redis_endpoint
  redis_port        = module.braintrust.redis_port

  brainstore_license_key         = var.brainstore_license_key
  function_secret_key            = module.braintrust.function_tools_secret_key
  brainstore_wal_footer_version  = var.brainstore_wal_footer_version
  skip_pg_for_brainstore_objects = var.skip_pg_for_brainstore_objects

  manage_braintrust_helm_release = true
  helm_chart_version             = var.eks_helm_chart_version

  api_helm                         = var.eks_api_helm
  brainstore_reader_helm           = var.eks_brainstore_reader_helm
  brainstore_fastreader_helm       = var.eks_brainstore_fastreader_helm
  brainstore_writer_helm           = var.eks_brainstore_writer_helm
  helm_chart_extra_values          = var.eks_helm_chart_extra_values
  prepare_for_destroy              = var.prepare_for_destroy
  use_auto_mode                    = true
  node_role_name                   = module.braintrust.eks_node_group_iam_role_name
  brainstore_instance_families     = var.eks_brainstore_instance_families
  brainstore_reader_instance_sizes = var.eks_brainstore_reader_instance_sizes
  brainstore_writer_instance_sizes = var.eks_brainstore_writer_instance_sizes

  depends_on = [module.braintrust]
}
