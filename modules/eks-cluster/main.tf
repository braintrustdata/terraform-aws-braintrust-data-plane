#----------------------------------------------------------------------------------------------
# EKS Cluster IAM Role
#----------------------------------------------------------------------------------------------
resource "aws_iam_role" "cluster" {
  name = "${var.deployment_name}-eks-cluster"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "sts:AssumeRole",
          "sts:TagSession"
        ]
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      }
    ]
  })

  permissions_boundary = var.permissions_boundary_arn

  tags = merge(
    {
      Name                     = "${var.deployment_name}-eks-cluster"
      BraintrustDeploymentName = var.deployment_name
    },
    var.custom_tags
  )
}

resource "aws_iam_role_policy_attachment" "cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster.name
}

#----------------------------------------------------------------------------------------------
# CloudWatch Log Group for EKS Control Plane
# Created before the cluster so Terraform controls retention and encryption.
# EKS auto-creates this log group if it doesn't exist — but without retention or tags.
#----------------------------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "cluster" {
  name              = "/aws/eks/${var.deployment_name}-eks/cluster"
  retention_in_days = var.cluster_log_retention_days == 0 ? null : var.cluster_log_retention_days

  tags = merge(
    {
      Name                     = "${var.deployment_name}-eks-logs"
      BraintrustDeploymentName = var.deployment_name
    },
    var.custom_tags
  )
}

#----------------------------------------------------------------------------------------------
# EKS Cluster
#----------------------------------------------------------------------------------------------
resource "aws_eks_cluster" "main" {
  name     = "${var.deployment_name}-eks"
  role_arn = aws_iam_role.cluster.arn
  version  = var.kubernetes_version

  access_config {
    authentication_mode                         = "API"
    bootstrap_cluster_creator_admin_permissions = true
  }

  vpc_config {
    subnet_ids = var.subnet_ids

    endpoint_private_access = var.enable_private_access
    endpoint_public_access  = var.enable_public_access
    public_access_cidrs     = var.public_access_cidrs

    security_group_ids = var.additional_security_group_ids
  }

  encryption_config {
    provider {
      key_arn = var.kms_key_arn
    }
    resources = ["secrets"]
  }

  enabled_cluster_log_types = var.cluster_log_types

  # Required by EKS API when Auto Mode (compute_config.enabled = true) is used.
  bootstrap_self_managed_addons = var.use_eks_auto_mode ? false : null

  # EKS Auto Mode: compute, load balancing, and block storage managed by EKS.
  # System and services node pools are handled by built-in node pools ("system", "general-purpose").
  # Brainstore nodes still use managed node groups for NVMe launch template support.
  dynamic "compute_config" {
    for_each = var.use_eks_auto_mode ? [1] : []
    content {
      enabled       = true
      node_pools    = ["general-purpose", "system"]
      node_role_arn = aws_iam_role.node_group.arn
    }
  }

  dynamic "kubernetes_network_config" {
    for_each = var.use_eks_auto_mode ? [1] : []
    content {
      elastic_load_balancing {
        enabled = true
      }
    }
  }

  dynamic "storage_config" {
    for_each = var.use_eks_auto_mode ? [1] : []
    content {
      block_storage {
        enabled = true
      }
    }
  }

  tags = merge(
    {
      Name                     = "${var.deployment_name}-eks"
      BraintrustDeploymentName = var.deployment_name
    },
    var.custom_tags
  )

  depends_on = [
    aws_iam_role_policy_attachment.cluster_policy,
    aws_cloudwatch_log_group.cluster,
    aws_iam_role_policy_attachment.cluster_compute_policy,
    aws_iam_role_policy_attachment.cluster_block_storage_policy,
    aws_iam_role_policy_attachment.cluster_load_balancing_policy,
    aws_iam_role_policy_attachment.cluster_networking_policy,
    aws_iam_role_policy_attachment.node_group_worker_minimal_policy,
    aws_iam_role_policy_attachment.node_group_ecr_pull_only_policy,
  ]
}

#----------------------------------------------------------------------------------------------
# EKS Node Group IAM Role
#----------------------------------------------------------------------------------------------
resource "aws_iam_role" "node_group" {
  name = "${var.deployment_name}-eks-node-group"

  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })

  permissions_boundary = var.permissions_boundary_arn

  tags = merge(
    {
      Name                     = "${var.deployment_name}-eks-node-group"
      BraintrustDeploymentName = var.deployment_name
    },
    var.custom_tags
  )
}

resource "aws_iam_role_policy_attachment" "node_group_worker_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.node_group.name
}

resource "aws_iam_role_policy_attachment" "node_group_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.node_group.name
}

resource "aws_iam_role_policy_attachment" "node_group_ecr_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.node_group.name
}

# Optional: SSM access for node debugging
resource "aws_iam_role_policy_attachment" "node_group_ssm_policy" {
  count      = var.enable_node_ssm ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.node_group.name
}

#----------------------------------------------------------------------------------------------
# System Node Group (for system pods like CoreDNS, kube-proxy, etc.)
# Not created when use_eks_auto_mode = true — EKS Auto Mode's built-in "system" node pool
# handles kube-system workloads automatically.
#----------------------------------------------------------------------------------------------
resource "aws_eks_node_group" "system" {
  count = var.use_eks_auto_mode ? 0 : 1

  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.deployment_name}-system"
  node_role_arn   = aws_iam_role.node_group.arn
  subnet_ids      = var.subnet_ids
  version         = var.kubernetes_version
  ami_type        = var.node_group_ami_type

  scaling_config {
    desired_size = var.system_node_group_desired_size
    max_size     = var.system_node_group_max_size
    min_size     = var.system_node_group_min_size
  }

  update_config {
    max_unavailable = 1
  }

  disk_size      = var.system_node_group_disk_size
  instance_types = [var.system_node_group_instance_type]
  capacity_type  = "ON_DEMAND"

  labels = {
    role = "system"
  }

  tags = merge(
    {
      Name                     = "${var.deployment_name}-system"
      BraintrustDeploymentName = var.deployment_name
    },
    var.custom_tags
  )

  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }

  depends_on = [
    aws_iam_role_policy_attachment.node_group_worker_policy,
    aws_iam_role_policy_attachment.node_group_cni_policy,
    aws_iam_role_policy_attachment.node_group_ecr_policy
  ]
}

#----------------------------------------------------------------------------------------------
# Services Node Group (for Braintrust API services)
# Not created when use_eks_auto_mode = true — EKS Auto Mode's built-in "general-purpose" node
# pool handles API service workloads and scales them automatically.
#----------------------------------------------------------------------------------------------
resource "aws_eks_node_group" "services" {
  count = var.use_eks_auto_mode ? 0 : 1

  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.deployment_name}-services"
  node_role_arn   = aws_iam_role.node_group.arn
  subnet_ids      = var.subnet_ids
  version         = var.kubernetes_version
  ami_type        = var.node_group_ami_type

  scaling_config {
    desired_size = var.services_node_group_desired_size
    max_size     = var.services_node_group_max_size
    min_size     = var.services_node_group_min_size
  }

  update_config {
    max_unavailable = 1
  }

  disk_size      = var.services_node_group_disk_size
  instance_types = [var.services_node_group_instance_type]
  capacity_type  = "ON_DEMAND"

  labels = {
    role = "services"
  }

  # Prevent unintended workloads from landing on services nodes.
  # API pods must include a matching toleration in their Helm values.
  taint {
    key    = "dedicated"
    value  = "services"
    effect = "NO_SCHEDULE"
  }

  tags = merge(
    {
      Name                     = "${var.deployment_name}-services"
      BraintrustDeploymentName = var.deployment_name
    },
    var.custom_tags
  )

  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }

  depends_on = [
    aws_iam_role_policy_attachment.node_group_worker_policy,
    aws_iam_role_policy_attachment.node_group_cni_policy,
    aws_iam_role_policy_attachment.node_group_ecr_policy
  ]
}

#----------------------------------------------------------------------------------------------
# Services Spot Node Group (burst capacity for Braintrust API services)
# Creates an optional fixed-capacity SPOT pool alongside the on-demand baseline.
# Not created when use_eks_auto_mode = true — Auto Mode handles burst scaling natively.
#----------------------------------------------------------------------------------------------
resource "aws_eks_node_group" "services_spot" {
  count = (!var.use_eks_auto_mode && var.enable_services_spot_node_group) ? 1 : 0

  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.deployment_name}-services-spot"
  node_role_arn   = aws_iam_role.node_group.arn
  subnet_ids      = var.subnet_ids
  version         = var.kubernetes_version
  ami_type        = var.node_group_ami_type

  scaling_config {
    desired_size = var.services_spot_node_group_min_size
    max_size     = var.services_spot_node_group_max_size
    min_size     = var.services_spot_node_group_min_size
  }

  update_config {
    max_unavailable = 1
  }

  disk_size      = var.services_node_group_disk_size
  instance_types = var.services_spot_node_group_instance_types
  capacity_type  = "SPOT"

  labels = {
    role = "services"
  }

  # Must match the taint on the on-demand services node group so that API pods
  # with a services toleration can land on either node group.
  taint {
    key    = "dedicated"
    value  = "services"
    effect = "NO_SCHEDULE"
  }

  tags = merge(
    {
      Name                     = "${var.deployment_name}-services-spot"
      BraintrustDeploymentName = var.deployment_name
    },
    var.custom_tags
  )

  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }

  depends_on = [
    aws_iam_role_policy_attachment.node_group_worker_policy,
    aws_iam_role_policy_attachment.node_group_cni_policy,
    aws_iam_role_policy_attachment.node_group_ecr_policy
  ]
}

#----------------------------------------------------------------------------------------------
# Brainstore Reader Node Group (for reader and fast-reader pods)
#----------------------------------------------------------------------------------------------
resource "aws_eks_node_group" "brainstore_reader" {
  count           = var.use_eks_auto_mode ? 0 : 1
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.deployment_name}-brainstore-reader"
  node_role_arn   = aws_iam_role.node_group.arn
  subnet_ids      = var.subnet_ids
  version         = var.kubernetes_version
  ami_type        = var.brainstore_node_group_ami_type

  scaling_config {
    desired_size = var.brainstore_reader_node_group_desired_size
    max_size     = var.brainstore_reader_node_group_max_size
    min_size     = var.brainstore_reader_node_group_min_size
  }

  update_config {
    max_unavailable = 1
  }

  instance_types = [var.brainstore_reader_node_group_instance_type]
  capacity_type  = "ON_DEMAND"

  labels = {
    role = "brainstore-reader"
  }

  # Prevent unintended workloads from landing on brainstore reader nodes.
  # Reader and fast-reader pods must include a matching toleration in their Helm values.
  taint {
    key    = "dedicated"
    value  = "brainstore"
    effect = "NO_SCHEDULE"
  }

  # Launch template formats and mounts the local NVMe instance store before node joins the cluster
  launch_template {
    id      = aws_launch_template.brainstore_nvme[0].id
    version = tostring(aws_launch_template.brainstore_nvme[0].latest_version)
  }

  tags = merge(
    {
      Name                     = "${var.deployment_name}-brainstore-reader"
      BraintrustDeploymentName = var.deployment_name
    },
    var.custom_tags
  )

  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }

  depends_on = [
    aws_iam_role_policy_attachment.node_group_worker_policy,
    aws_iam_role_policy_attachment.node_group_cni_policy,
    aws_iam_role_policy_attachment.node_group_ecr_policy
  ]
}

#----------------------------------------------------------------------------------------------
# Brainstore Writer Node Group (for writer pods — 2× CPU/memory of the reader nodes)
#----------------------------------------------------------------------------------------------
resource "aws_eks_node_group" "brainstore_writer" {
  count           = var.use_eks_auto_mode ? 0 : 1
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.deployment_name}-brainstore-writer"
  node_role_arn   = aws_iam_role.node_group.arn
  subnet_ids      = var.subnet_ids
  version         = var.kubernetes_version
  ami_type        = var.brainstore_node_group_ami_type

  scaling_config {
    desired_size = var.brainstore_writer_node_group_desired_size
    max_size     = var.brainstore_writer_node_group_max_size
    min_size     = var.brainstore_writer_node_group_min_size
  }

  update_config {
    max_unavailable = 1
  }

  instance_types = [var.brainstore_writer_node_group_instance_type]
  capacity_type  = "ON_DEMAND"

  labels = {
    role = "brainstore-writer"
  }

  # Prevent unintended workloads from landing on brainstore writer nodes.
  # Writer pods must include a matching toleration in their Helm values.
  taint {
    key    = "dedicated"
    value  = "brainstore"
    effect = "NO_SCHEDULE"
  }

  # Launch template formats and mounts the local NVMe instance store before node joins the cluster
  launch_template {
    id      = aws_launch_template.brainstore_nvme[0].id
    version = tostring(aws_launch_template.brainstore_nvme[0].latest_version)
  }

  tags = merge(
    {
      Name                     = "${var.deployment_name}-brainstore-writer"
      BraintrustDeploymentName = var.deployment_name
    },
    var.custom_tags
  )

  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }

  depends_on = [
    aws_iam_role_policy_attachment.node_group_worker_policy,
    aws_iam_role_policy_attachment.node_group_cni_policy,
    aws_iam_role_policy_attachment.node_group_ecr_policy
  ]
}

#----------------------------------------------------------------------------------------------
# Brainstore Spot Node Group (burst capacity for Brainstore workloads)
# Creates an optional fixed-capacity SPOT pool alongside the on-demand baseline. All instance types must be
# NVMe-backed Graviton instances so the pre-bootstrap mount script runs correctly on every node.
# Spot interruptions cause cache loss; Brainstore pods rehydrate from S3 on restart.
# Set enable_brainstore_spot_node_group = true to create this group.
#----------------------------------------------------------------------------------------------
resource "aws_eks_node_group" "brainstore_spot" {
  count = !var.use_eks_auto_mode && var.enable_brainstore_spot_node_group ? 1 : 0

  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.deployment_name}-brainstore-spot"
  node_role_arn   = aws_iam_role.node_group.arn
  subnet_ids      = var.subnet_ids
  version         = var.kubernetes_version
  ami_type        = var.brainstore_node_group_ami_type

  scaling_config {
    desired_size = var.brainstore_spot_node_group_min_size
    max_size     = var.brainstore_spot_node_group_max_size
    min_size     = var.brainstore_spot_node_group_min_size
  }

  update_config {
    max_unavailable = 1
  }

  instance_types = var.brainstore_spot_node_group_instance_types
  capacity_type  = "SPOT"

  labels = {
    role = "brainstore-reader"
  }

  # Must match the taint on the on-demand brainstore reader node group so that reader
  # and fast-reader pods can land on either node group.
  taint {
    key    = "dedicated"
    value  = "brainstore"
    effect = "NO_SCHEDULE"
  }

  # Same NVMe launch template as the on-demand group — formats and mounts
  # local NVMe instance store before the node joins the cluster.
  launch_template {
    id      = aws_launch_template.brainstore_nvme[0].id
    version = tostring(aws_launch_template.brainstore_nvme[0].latest_version)
  }

  tags = merge(
    {
      Name                     = "${var.deployment_name}-brainstore-spot"
      BraintrustDeploymentName = var.deployment_name
    },
    var.custom_tags
  )

  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }

  depends_on = [
    aws_iam_role_policy_attachment.node_group_worker_policy,
    aws_iam_role_policy_attachment.node_group_cni_policy,
    aws_iam_role_policy_attachment.node_group_ecr_policy
  ]
}

#----------------------------------------------------------------------------------------------
# Brainstore Writer Spot Node Group (burst capacity for writer workloads)
# Uses larger NVMe-backed instances (2× reader size) to match writer resource requirements.
# Set enable_brainstore_writer_spot_node_group = true to create this group.
#----------------------------------------------------------------------------------------------
resource "aws_eks_node_group" "brainstore_writer_spot" {
  count = !var.use_eks_auto_mode && var.enable_brainstore_writer_spot_node_group ? 1 : 0

  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.deployment_name}-brainstore-writer-spot"
  node_role_arn   = aws_iam_role.node_group.arn
  subnet_ids      = var.subnet_ids
  version         = var.kubernetes_version
  ami_type        = var.brainstore_node_group_ami_type

  scaling_config {
    desired_size = var.brainstore_writer_spot_node_group_min_size
    max_size     = var.brainstore_writer_spot_node_group_max_size
    min_size     = var.brainstore_writer_spot_node_group_min_size
  }

  update_config {
    max_unavailable = 1
  }

  instance_types = var.brainstore_writer_spot_node_group_instance_types
  capacity_type  = "SPOT"

  labels = {
    role = "brainstore-writer"
  }

  # Must match the taint on the on-demand brainstore writer node group so that
  # writer pods can land on either node group.
  taint {
    key    = "dedicated"
    value  = "brainstore"
    effect = "NO_SCHEDULE"
  }

  launch_template {
    id      = aws_launch_template.brainstore_nvme[0].id
    version = tostring(aws_launch_template.brainstore_nvme[0].latest_version)
  }

  tags = merge(
    {
      Name                     = "${var.deployment_name}-brainstore-writer-spot"
      BraintrustDeploymentName = var.deployment_name
    },
    var.custom_tags
  )

  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }

  depends_on = [
    aws_iam_role_policy_attachment.node_group_worker_policy,
    aws_iam_role_policy_attachment.node_group_cni_policy,
    aws_iam_role_policy_attachment.node_group_ecr_policy
  ]
}

#----------------------------------------------------------------------------------------------
# Brainstore NVMe Launch Template
# Formats and mounts local NVMe instance store volumes before the node joins the cluster.
# Runs as a pre-bootstrap shell script via MIME multipart user data.
#
# The script auto-detects all NVMe instance store devices at boot:
#   1 device  — formatted and mounted directly
#   2+ devices — striped as RAID 0 for maximum aggregate throughput
#
# Tested with c8gd (Graviton4 NVMe) instances. Also compatible with c6id and other
# NVMe-backed families.
#----------------------------------------------------------------------------------------------
resource "aws_launch_template" "brainstore_nvme" {
  count       = var.use_eks_auto_mode ? 0 : 1
  name_prefix = "${var.deployment_name}-brainstore-"
  description = "Formats and mounts local NVMe instance store for Brainstore nodes"

  # MIME multipart user data is required for AL2023 managed node groups.
  # The shell script runs before EKS bootstraps the node, ensuring the NVMe
  # volume is mounted before any pods are scheduled.
  user_data = base64encode(<<-EOT
  MIME-Version: 1.0
  Content-Type: multipart/mixed; boundary="==BOUNDARY=="

  --==BOUNDARY==
  Content-Type: application/node.eks.aws

  apiVersion: node.eks.aws/v1alpha1
  kind: NodeConfig
  spec:
    instance:
      localStorage:
        strategy: RAID0

  --==BOUNDARY==--
  EOT
  )

  tag_specifications {
    resource_type = "instance"
    tags = merge(
      {
        Name                     = "${var.deployment_name}-brainstore"
        BraintrustDeploymentName = var.deployment_name
      },
      var.custom_tags
    )
  }

  tags = merge(
    {
      Name                     = "${var.deployment_name}-brainstore-nvme-lt"
      BraintrustDeploymentName = var.deployment_name
    },
    var.custom_tags
  )

  lifecycle {
    create_before_destroy = true
  }
}

#----------------------------------------------------------------------------------------------
# EKS Addons
# vpc-cni, kube-proxy, and coredns are managed by EKS Auto Mode when use_eks_auto_mode = true.
# eks-pod-identity-agent is always installed regardless of mode.
#----------------------------------------------------------------------------------------------
resource "aws_eks_addon" "vpc_cni" {
  count = var.use_eks_auto_mode ? 0 : 1

  cluster_name  = aws_eks_cluster.main.name
  addon_name    = "vpc-cni"
  addon_version = var.vpc_cni_addon_version != null ? var.vpc_cni_addon_version : null

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = merge(
    {
      Name                     = "${var.deployment_name}-vpc-cni"
      BraintrustDeploymentName = var.deployment_name
    },
    var.custom_tags
  )
}

resource "aws_eks_addon" "kube_proxy" {
  count = var.use_eks_auto_mode ? 0 : 1

  cluster_name  = aws_eks_cluster.main.name
  addon_name    = "kube-proxy"
  addon_version = var.kube_proxy_addon_version != null ? var.kube_proxy_addon_version : null

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = merge(
    {
      Name                     = "${var.deployment_name}-kube-proxy"
      BraintrustDeploymentName = var.deployment_name
    },
    var.custom_tags
  )
}

resource "aws_eks_addon" "coredns" {
  count = var.use_eks_auto_mode ? 0 : 1

  cluster_name  = aws_eks_cluster.main.name
  addon_name    = "coredns"
  addon_version = var.coredns_addon_version != null ? var.coredns_addon_version : null

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = merge(
    {
      Name                     = "${var.deployment_name}-coredns"
      BraintrustDeploymentName = var.deployment_name
    },
    var.custom_tags
  )

  depends_on = [
    aws_eks_node_group.system
  ]
}


resource "aws_eks_addon" "pod_identity" {
  cluster_name  = aws_eks_cluster.main.name
  addon_name    = "eks-pod-identity-agent"
  addon_version = var.pod_identity_addon_version != null ? var.pod_identity_addon_version : null

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = merge(
    {
      Name                     = "${var.deployment_name}-pod-identity-agent"
      BraintrustDeploymentName = var.deployment_name
    },
    var.custom_tags
  )
}
