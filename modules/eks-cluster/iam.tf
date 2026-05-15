# IAM roles used by Kubernetes control-plane add-ons. Workload roles for the
# Braintrust API and Brainstore are created by services-common and associated in
# this module.

#----------------------------------------------------------------------------------------------
# EKS Auto Mode IAM — Cluster Role
# These four managed policies are required for the cluster role when EKS Auto Mode is enabled.
# They grant EKS permission to manage compute (node pools), block storage (EBS), load balancing
# (NLBs/ALBs), and networking (ENIs/IPs) on your behalf.
#----------------------------------------------------------------------------------------------
resource "aws_iam_role_policy_attachment" "cluster_compute_policy" {
  count      = var.use_eks_auto_mode ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSComputePolicy"
  role       = aws_iam_role.cluster.name
}

resource "aws_iam_role_policy_attachment" "cluster_block_storage_policy" {
  count      = var.use_eks_auto_mode ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSBlockStoragePolicy"
  role       = aws_iam_role.cluster.name
}

resource "aws_iam_role_policy_attachment" "cluster_load_balancing_policy" {
  count      = var.use_eks_auto_mode ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSLoadBalancingPolicy"
  role       = aws_iam_role.cluster.name
}

resource "aws_iam_role_policy_attachment" "cluster_networking_policy" {
  count      = var.use_eks_auto_mode ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSNetworkingPolicy"
  role       = aws_iam_role.cluster.name
}

#----------------------------------------------------------------------------------------------
# EKS Auto Mode IAM — Node Role
# Auto Mode-provisioned nodes use a reduced permission set compared to traditional managed
# node groups. AmazonEKSWorkerNodeMinimalPolicy replaces AmazonEKSWorkerNodePolicy, and
# AmazonEC2ContainerRegistryPullOnly (read-only) replaces the broader ReadOnly policy.
# These are attached alongside the standard policies so the same role works for both
# Auto Mode node pools and the Brainstore managed node groups.
#----------------------------------------------------------------------------------------------
resource "aws_iam_role_policy_attachment" "node_group_worker_minimal_policy" {
  count      = var.use_eks_auto_mode ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodeMinimalPolicy"
  role       = aws_iam_role.node_group.name
}

resource "aws_iam_role_policy_attachment" "node_group_ecr_pull_only_policy" {
  count      = var.use_eks_auto_mode ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPullOnly"
  role       = aws_iam_role.node_group.name
}

resource "aws_iam_policy" "lb_controller" {
  name   = "${var.deployment_name}-lb-controller"
  policy = file("${path.module}/assets/aws-lb-controller-iam-policy.json")

  tags = merge(
    {
      Name                     = "${var.deployment_name}-lb-controller"
      BraintrustDeploymentName = var.deployment_name
    },
    var.custom_tags
  )
}

resource "aws_iam_role" "lb_controller" {
  name = "${var.deployment_name}-lb-controller"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "pods.eks.amazonaws.com"
        }
        Action = [
          "sts:AssumeRole",
          "sts:TagSession"
        ]
      }
    ]
  })

  permissions_boundary = var.permissions_boundary_arn

  tags = merge(
    {
      Name                     = "${var.deployment_name}-lb-controller"
      BraintrustDeploymentName = var.deployment_name
    },
    var.custom_tags
  )
}

resource "aws_iam_role_policy_attachment" "lb_controller" {
  role       = aws_iam_role.lb_controller.name
  policy_arn = aws_iam_policy.lb_controller.arn
}

resource "aws_eks_pod_identity_association" "lb_controller" {
  cluster_name    = aws_eks_cluster.main.name
  namespace       = "kube-system"
  service_account = var.aws_load_balancer_controller_service_account
  role_arn        = aws_iam_role.lb_controller.arn

  tags = merge(
    {
      Name                     = "${var.deployment_name}-lb-controller"
      BraintrustDeploymentName = var.deployment_name
    },
    var.custom_tags
  )

  depends_on = [
    aws_eks_addon.pod_identity,
    aws_iam_role_policy_attachment.lb_controller,
  ]
}

resource "aws_eks_pod_identity_association" "braintrust_api" {
  cluster_name    = aws_eks_cluster.main.name
  namespace       = var.braintrust_namespace
  service_account = var.braintrust_api_service_account
  role_arn        = var.braintrust_api_role_arn

  tags = merge(
    {
      Name                     = "${var.deployment_name}-braintrust-api"
      BraintrustDeploymentName = var.deployment_name
    },
    var.custom_tags
  )

  depends_on = [
    aws_eks_addon.pod_identity,
  ]
}

resource "aws_eks_pod_identity_association" "brainstore" {
  cluster_name    = aws_eks_cluster.main.name
  namespace       = var.braintrust_namespace
  service_account = var.brainstore_service_account
  role_arn        = var.brainstore_role_arn

  tags = merge(
    {
      Name                     = "${var.deployment_name}-brainstore"
      BraintrustDeploymentName = var.deployment_name
    },
    var.custom_tags
  )

  depends_on = [
    aws_eks_addon.pod_identity,
  ]
}
