locals {
  common_tags = merge({
    BraintrustDeploymentName = var.deployment_name
  }, var.custom_tags)

  # Prefer an explicitly provided OIDC issuer URL. For externally managed EKS
  # clusters, fall back to looking up the cluster only when IRSA is enabled and
  # the caller did not pass the issuer URL directly.
  eks_oidc_issuer_url = var.enable_eks_irsa ? coalesce(
    var.eks_cluster_oidc_issuer_url,
    try(data.aws_eks_cluster.cluster[0].identity[0].oidc[0].issuer, null)
  ) : null
}

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

data "aws_eks_cluster" "cluster" {
  count = var.enable_eks_irsa && var.eks_cluster_arn != null && var.eks_cluster_oidc_issuer_url == null ? 1 : 0
  name  = split("/", var.eks_cluster_arn)[1]
}
