resource "aws_iam_role" "cluster" {
  name                 = "${var.deployment_name}-sandbox-cluster"
  permissions_boundary = var.permissions_boundary_arn
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Action = "sts:AssumeRole", Principal = { Service = "eks.amazonaws.com" } }]
  })
  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "cluster" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role" "nodes" {
  name                 = "${var.deployment_name}-sandbox-nodes"
  permissions_boundary = var.permissions_boundary_arn
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Action = "sts:AssumeRole", Principal = { Service = "ec2.amazonaws.com" } }]
  })
  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "nodes" {
  for_each = toset(["AmazonEKSWorkerNodePolicy", "AmazonEC2ContainerRegistryPullOnly"])

  role       = aws_iam_role.nodes.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/${each.value}"
}

# Scope VPC CNI writes to this cluster's ENIs, VPC, security groups and nodes.
resource "aws_iam_role_policy" "cni" {
  name = "sandbox-network-interfaces"
  role = aws_iam_role.nodes.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ec2:DescribeInstances", "ec2:DescribeTags", "ec2:DescribeNetworkInterfaces", "ec2:DescribeInstanceTypes", "ec2:DescribeSubnets", "ec2:DescribeSecurityGroups"]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = "ec2:CreateNetworkInterface"
        Resource = "arn:${data.aws_partition.current.partition}:ec2:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:network-interface/*"
        Condition = { StringEquals = {
          "aws:RequestTag/cluster.k8s.amazonaws.com/name" = local.cluster_name
        } }
      },
      {
        Effect   = "Allow"
        Action   = "ec2:CreateNetworkInterface"
        Resource = "arn:${data.aws_partition.current.partition}:ec2:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:subnet/*"
        Condition = { ArnEquals = {
          "ec2:Vpc" = "arn:${data.aws_partition.current.partition}:ec2:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:vpc/${var.vpc_id}"
        } }
      },
      {
        Effect = "Allow"
        Action = ["ec2:CreateNetworkInterface", "ec2:ModifyNetworkInterfaceAttribute"]
        Resource = [for id in [aws_security_group.system.id, aws_security_group.workers.id, aws_security_group.public_egress.id] :
          "arn:${data.aws_partition.current.partition}:ec2:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:security-group/${id}"
        ]
      },
      {
        Effect   = "Allow"
        Action   = "ec2:CreateTags"
        Resource = "arn:${data.aws_partition.current.partition}:ec2:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:network-interface/*"
        Condition = { StringEquals = {
          "ec2:CreateAction"                              = "CreateNetworkInterface"
          "aws:RequestTag/cluster.k8s.amazonaws.com/name" = local.cluster_name
        } }
      },
      {
        Effect   = "Allow"
        Action   = ["ec2:CreateTags", "ec2:DeleteNetworkInterface", "ec2:AssignPrivateIpAddresses", "ec2:UnassignPrivateIpAddresses", "ec2:AttachNetworkInterface", "ec2:DetachNetworkInterface", "ec2:ModifyNetworkInterfaceAttribute"]
        Resource = "arn:${data.aws_partition.current.partition}:ec2:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:network-interface/*"
        Condition = { StringEquals = {
          "aws:ResourceTag/cluster.k8s.amazonaws.com/name" = local.cluster_name
        } }
      },
      {
        Effect   = "Allow"
        Action   = ["ec2:AttachNetworkInterface", "ec2:DetachNetworkInterface", "ec2:ModifyNetworkInterfaceAttribute"]
        Resource = "arn:${data.aws_partition.current.partition}:ec2:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:instance/*"
        Condition = { StringEquals = {
          "aws:ResourceTag/eks:cluster-name" = local.cluster_name
        } }
      },
    ]
  })
}

resource "aws_iam_role" "dns" {
  name                 = "${var.deployment_name}-sandbox-dns"
  permissions_boundary = var.permissions_boundary_arn
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "pods.eks.amazonaws.com" }
      Action    = ["sts:AssumeRole", "sts:TagSession"]
      Condition = { StringEquals = {
        "aws:RequestTag/eks-cluster-arn"            = aws_eks_cluster.sandbox.arn
        "aws:RequestTag/kubernetes-namespace"       = local.namespace
        "aws:RequestTag/kubernetes-service-account" = "external-dns"
      } }
    }]
  })
  tags = local.common_tags
}

resource "aws_iam_role_policy" "dns" {
  name = "sandbox-private-dns"
  role = aws_iam_role.dns.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["route53:ChangeResourceRecordSets", "route53:ListResourceRecordSets", "route53:ListTagsForResources"]
        Resource = aws_route53_zone.sandbox.arn
      },
      { Effect = "Allow", Action = "route53:ListHostedZones", Resource = "*" },
    ]
  })
}

resource "aws_iam_role" "autoscaler" {
  name                 = "${var.deployment_name}-sandbox-autoscaler"
  permissions_boundary = var.permissions_boundary_arn
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "pods.eks.amazonaws.com" }
      Action    = ["sts:AssumeRole", "sts:TagSession"]
      Condition = { StringEquals = {
        "aws:RequestTag/eks-cluster-arn"            = aws_eks_cluster.sandbox.arn
        "aws:RequestTag/kubernetes-namespace"       = local.namespace
        "aws:RequestTag/kubernetes-service-account" = "sandbox-node-autoscaler"
      } }
    }]
  })
  tags = local.common_tags
}

resource "aws_iam_role_policy" "autoscaler" {
  name = "sandbox-node-capacity"
  role = aws_iam_role.autoscaler.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "autoscaling:DescribeAutoScalingGroups", "autoscaling:DescribeAutoScalingInstances", "autoscaling:DescribeLaunchConfigurations",
          "autoscaling:DescribeScalingActivities", "autoscaling:DescribeTags", "ec2:DescribeImages", "ec2:DescribeInstanceTypes",
          "ec2:DescribeLaunchTemplateVersions", "ec2:GetInstanceTypesFromInstanceRequirements",
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = "eks:DescribeNodegroup"
        Resource = "arn:${data.aws_partition.current.partition}:eks:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:nodegroup/${local.cluster_name}/*"
      },
      {
        Effect   = "Allow"
        Action   = ["autoscaling:SetDesiredCapacity", "autoscaling:TerminateInstanceInAutoScalingGroup"]
        Resource = "arn:${data.aws_partition.current.partition}:autoscaling:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:autoScalingGroup:*:autoScalingGroupName/*"
        Condition = {
          StringEquals = { "autoscaling:ResourceTag/eks:cluster-name" = local.cluster_name }
          StringLike   = { "autoscaling:ResourceTag/eks:nodegroup-name" = "sandbox-*" }
        }
      },
    ]
  })
}

resource "aws_iam_role" "controller" {
  name                 = "${var.deployment_name}-sandbox-controller"
  permissions_boundary = var.permissions_boundary_arn
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "pods.eks.amazonaws.com" }
      Action    = ["sts:AssumeRole", "sts:TagSession"]
      Condition = { StringEquals = {
        "aws:RequestTag/eks-cluster-arn"            = aws_eks_cluster.sandbox.arn
        "aws:RequestTag/kubernetes-namespace"       = local.namespace
        "aws:RequestTag/kubernetes-service-account" = "sandbox-worker-controller"
      } }
    }]
  })
  tags = local.common_tags
}

resource "aws_iam_role_policy" "controller" {
  name = "loop-runtime-task-count"
  role = aws_iam_role.controller.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "ecs:DescribeServices"
      Resource = "arn:${data.aws_partition.current.partition}:ecs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:service/${var.ecs_cluster_name}/${var.loop_runtime_service_name}"
    }]
  })
}
