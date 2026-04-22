# Composition of the EKS cluster and EKS-deploy submodules.
# All resource-level logic lives under modules/eks-cluster/ and
# modules/eks-deploy/. This file is just wiring.

locals {
  # Kubernetes namespace the Braintrust workloads run in. Falls back to
  # "braintrust" when var.eks_namespace is null (keeps the existing
  # non-EKS behavior of the var while providing a sensible default here).
  eks_namespace_resolved = coalesce(var.eks_namespace, "braintrust")

  # Safe accessors for count-gated module outputs — one() returns null for empty lists.
  eks_cluster_arn_val                 = one(module.eks_cluster[*].cluster_arn)
  eks_cluster_name_val                = one(module.eks_cluster[*].cluster_name)
  eks_cluster_endpoint_val            = one(module.eks_cluster[*].cluster_endpoint)
  eks_cluster_ca_certificate_val      = one(module.eks_cluster[*].cluster_certificate_authority_data)
  eks_oidc_provider_arn               = one(module.eks_cluster[*].oidc_provider_arn)
  eks_node_security_group_id          = one(module.eks_cluster[*].node_security_group_id)
  eks_api_iam_trust_policy            = one(module.eks_cluster[*].api_iam_trust_policy)
  eks_brainstore_iam_trust_policy     = one(module.eks_cluster[*].brainstore_iam_trust_policy)
  eks_lb_controller_role_arn          = one(module.eks_cluster[*].lb_controller_role_arn)
  eks_nlb_arn_val                     = one(module.eks_cluster[*].nlb_arn)
  eks_nlb_name_val                    = one(module.eks_cluster[*].nlb_name)
  eks_nlb_security_group_id           = one(module.eks_cluster[*].nlb_security_group_id)
  eks_cloudfront_domain_name          = one(module.eks_cluster[*].cloudfront_distribution_domain_name)
  eks_cloudfront_arn                  = one(module.eks_cluster[*].cloudfront_distribution_arn)
  eks_cloudfront_hosted_zone_id       = one(module.eks_cluster[*].cloudfront_distribution_hosted_zone_id)
}

module "eks_cluster" {
  source = "./modules/eks-cluster"
  count  = var.create_eks_cluster ? 1 : 0

  deployment_name          = var.deployment_name
  custom_tags              = var.custom_tags
  permissions_boundary_arn = var.permissions_boundary_arn

  vpc_id = local.main_vpc_id
  private_subnet_ids = [
    local.main_vpc_private_subnet_1_id,
    local.main_vpc_private_subnet_2_id,
    local.main_vpc_private_subnet_3_id,
  ]

  eks_namespace          = local.eks_namespace_resolved
  eks_kubernetes_version = var.eks_kubernetes_version
  eks_node_instance_type = var.eks_node_instance_type
  eks_node_min_size      = var.eks_node_min_size
  eks_node_max_size      = var.eks_node_max_size
  eks_node_desired_size  = var.eks_node_desired_size

  cloudfront_price_class = var.cloudfront_price_class
  custom_domain          = var.custom_domain
  custom_certificate_arn = var.custom_certificate_arn
  waf_acl_id             = var.waf_acl_id
}

module "eks_deploy" {
  source = "./modules/eks-deploy"
  count  = var.create_eks_cluster ? 1 : 0

  deployment_name     = var.deployment_name
  custom_tags         = var.custom_tags
  braintrust_org_name = var.braintrust_org_name
  namespace           = local.eks_namespace_resolved

  cluster_name           = module.eks_cluster[0].cluster_name
  vpc_id                 = local.main_vpc_id
  lb_controller_role_arn = module.eks_cluster[0].lb_controller_role_arn
  nlb_security_group_id  = module.eks_cluster[0].nlb_security_group_id
  nlb_name               = module.eks_cluster[0].nlb_name

  # IAM role ARNs come from services_common, which in turn consumed the
  # trust policies output by eks_cluster above. This forms a linear chain:
  # eks_cluster -> services_common -> eks_deploy.
  api_handler_role_arn    = module.services_common.api_handler_role_arn
  brainstore_iam_role_arn = module.services_common.brainstore_iam_role_arn

  brainstore_bucket_name  = module.storage.brainstore_bucket_id
  response_bucket_name    = module.storage.lambda_responses_bucket_id
  code_bundle_bucket_name = module.storage.code_bundle_bucket_id

  postgres_host     = module.database.postgres_database_address
  postgres_port     = module.database.postgres_database_port
  postgres_username = module.database.postgres_database_username
  postgres_password = module.database.postgres_database_password
  redis_host        = module.redis.redis_endpoint
  redis_port        = module.redis.redis_port

  brainstore_license_key         = var.brainstore_license_key
  brainstore_wal_footer_version  = var.brainstore_wal_footer_version
  skip_pg_for_brainstore_objects = var.skip_pg_for_brainstore_objects

  helm_chart_version         = var.helm_chart_version
  api_helm                   = var.eks_api_helm
  brainstore_reader_helm     = var.eks_brainstore_reader_helm
  brainstore_fastreader_helm = var.eks_brainstore_fastreader_helm
  brainstore_writer_helm     = var.eks_brainstore_writer_helm
  helm_chart_extra_values    = var.eks_helm_chart_extra_values
}
