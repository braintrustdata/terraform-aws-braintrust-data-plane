locals {
  common_tags = {
    BraintrustDeploymentName = var.deployment_name
  }

  # OIDC issuer URL for EKS cluster. This is used when optionally enabling IRSA (Identity Role for Service Accounts)
  eks_oidc_issuer_url = var.eks_cluster_arn != null && var.enable_eks_irsa ? data.aws_eks_cluster.cluster[0].identity[0].oidc[0].issuer : null
}

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

data "aws_eks_cluster" "cluster" {
  count = var.eks_cluster_arn != null && var.enable_eks_irsa ? 1 : 0
  name  = split("/", var.eks_cluster_arn)[1]
}
