locals {
  common_tags = merge({
    BraintrustDeploymentName = var.deployment_name
  }, var.custom_tags)
}

# EKS Cluster — uses terraform-aws-modules/eks v21, which handles:
#   - Cluster IAM role
#   - OIDC provider (enable_irsa = true by default)
#   - Core addons (vpc-cni, coredns, kube-proxy) via the `addons` map
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name               = "${var.deployment_name}-eks"
  kubernetes_version = var.eks_kubernetes_version

  # Terraform must be able to reach the cluster API during apply.
  endpoint_public_access = true

  vpc_id     = var.vpc_id
  subnet_ids = var.private_subnet_ids

  # Core addons — not auto-installed by EKS, must be explicit.
  addons = {
    vpc-cni    = {}
    coredns    = {}
    kube-proxy = {}
  }

  eks_managed_node_groups = {
    main = {
      # Explicit names so the node IAM role and launch template are prefixed
      # with the deployment name (use_name_prefix = false gives exact names,
      # matching the rest of the top-level module's naming style).
      iam_role_name                   = "${var.deployment_name}-eks-nodes"
      iam_role_use_name_prefix        = false
      launch_template_name            = "${var.deployment_name}-eks-nodes"
      launch_template_use_name_prefix = false
      instance_types                  = [var.eks_node_instance_type]
      min_size                        = var.eks_node_min_size
      max_size                        = var.eks_node_max_size
      desired_size                    = var.eks_node_desired_size
    }
  }

  tags = local.common_tags
}
