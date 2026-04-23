# EKS cluster in Auto Mode. AWS manages node provisioning (Karpenter under
# the hood), core addons (vpc-cni, coredns, kube-proxy, Pod Identity Agent),
# the EBS CSI driver, and the AWS Load Balancer Controller. We only have to
# own the cluster + node IAM roles (iam.tf), VPC wiring, and whatever
# Braintrust-specific K8s objects the eks-deploy submodule owns.

resource "aws_eks_cluster" "this" {
  name     = "${var.deployment_name}-eks"
  version  = var.eks_kubernetes_version
  role_arn = aws_iam_role.cluster.arn

  vpc_config {
    subnet_ids             = var.private_subnet_ids
    endpoint_public_access = true
  }

  access_config {
    # "API" uses EKS access entries exclusively (no aws-auth configmap).
    # bootstrap_cluster_creator_admin_permissions grants admin to the
    # principal running terraform apply, so we can kubectl in for debugging.
    authentication_mode                         = "API"
    bootstrap_cluster_creator_admin_permissions = true
  }

  # Enable Auto Mode.
  compute_config {
    enabled       = true
    node_pools    = ["general-purpose"]
    node_role_arn = aws_iam_role.node.arn
  }

  # Enable the built-in EBS CSI driver (Auto Mode manages it).
  storage_config {
    block_storage {
      enabled = true
    }
  }

  # Enable the built-in AWS Load Balancer Controller (Auto Mode manages it).
  # This is what lets the Braintrust api Service (type LoadBalancer) produce
  # an NLB, and what adopts the pre-created NLB via annotations.
  kubernetes_network_config {
    elastic_load_balancing {
      enabled = true
    }
  }

  tags = local.common_tags

  # Attach the managed policies before the cluster tries to use them.
  depends_on = [aws_iam_role_policy_attachment.cluster_policy]
}
