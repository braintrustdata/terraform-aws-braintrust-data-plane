# Composition of the EKS Auto Mode cluster and the Braintrust deployment.
# All resource-level logic lives under modules/eks-cluster/ and
# modules/eks-deploy/. This file is just wiring.
#
# Ordering: module.eks_cluster -> module.services_common -> module.eks_deploy
#
#   1. eks_cluster provisions the cluster and exports cluster_arn, which
#      services_common needs to build a Pod Identity trust policy scoped
#      to this cluster + namespace.
#   2. services_common creates the API and Brainstore IAM roles with the
#      Pod Identity trust. Role ARNs flow out to...
#   3. eks_deploy, which (a) creates Pod Identity associations binding
#      each K8s service account to its IAM role, (b) creates the
#      namespace, Secret, custom NodeClass/NodePool, and Braintrust Helm
#      release.
#
# The middle step forces the two-submodule split: services_common is
# shared with the non-EKS deployment path so it can't be wrapped inside
# an EKS-only submodule.

locals {
  # Kubernetes namespace for Braintrust workloads. Falls back to
  # "braintrust" when var.eks_namespace is null.
  eks_namespace_resolved = coalesce(var.eks_namespace, "braintrust")

  # Safe accessors (one() returns null for empty/count=0 module lists) for
  # eks_cluster outputs consumed by main.tf's services_common +
  # database/redis wiring and by outputs.tf's api_url / cloudfront_*.
  eks_cluster_arn_val           = one(module.eks_cluster[*].cluster_arn)
  eks_cluster_security_group_id = one(module.eks_cluster[*].cluster_security_group_id)
  eks_cloudfront_domain_name    = one(module.eks_cluster[*].cloudfront_distribution_domain_name)
  eks_cloudfront_arn            = one(module.eks_cluster[*].cloudfront_distribution_arn)
  eks_cloudfront_hosted_zone_id = one(module.eks_cluster[*].cloudfront_distribution_hosted_zone_id)
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

  eks_kubernetes_version = var.eks_kubernetes_version

  cloudfront_price_class = var.cloudfront_price_class
  custom_domain          = var.custom_domain
  custom_certificate_arn = var.custom_certificate_arn
  waf_acl_id             = var.waf_acl_id
  use_global_ai_proxy    = var.use_global_ai_proxy
}

module "eks_deploy" {
  source = "./modules/eks-deploy"
  count  = var.create_eks_cluster ? 1 : 0

  deployment_name     = var.deployment_name
  custom_tags         = var.custom_tags
  braintrust_org_name = var.braintrust_org_name
  namespace           = local.eks_namespace_resolved

  cluster_name          = module.eks_cluster[0].cluster_name
  node_iam_role_name    = module.eks_cluster[0].node_iam_role_name
  nlb_security_group_id = module.eks_cluster[0].nlb_security_group_id
  nlb_name              = module.eks_cluster[0].nlb_name

  # IAM role ARNs come from services_common, which consumes the cluster
  # ARN output by eks_cluster above — eks_cluster -> services_common -> eks_deploy.
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

  brainstore_nodepool_instance_families = var.eks_brainstore_nodepool_instance_families

  helm_chart_version         = var.helm_chart_version
  api_helm                   = var.eks_api_helm
  brainstore_reader_helm     = var.eks_brainstore_reader_helm
  brainstore_fastreader_helm = var.eks_brainstore_fastreader_helm
  brainstore_writer_helm     = var.eks_brainstore_writer_helm
  helm_chart_extra_values    = var.eks_helm_chart_extra_values
}
