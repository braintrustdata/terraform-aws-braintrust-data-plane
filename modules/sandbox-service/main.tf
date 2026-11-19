locals {
  iam_tags = merge(local.common_tags, { BraintrustIAMOwner = "braintrust" })
  common_tags = merge(var.custom_tags, {
    BraintrustDeploymentName = var.deployment_name
  })
  versions        = jsondecode(file("${path.module}/VERSIONS.json"))
  cluster_name    = "${var.deployment_name}-sandbox"
  namespace       = "braintrust-sandbox"
  hostname        = "nodes.${var.deployment_name}.sandbox.internal"
  artifact_bucket = "braintrust-cf-${data.aws_region.current.region}"
  worker_revision = "${aws_launch_template.workers.id}-${aws_launch_template.workers.latest_version}-${substr(sha256(jsonencode({ version = aws_eks_cluster.sandbox.version, instance_types = var.instance_types, subnet_ids = var.private_subnet_ids, ami_type = "AL2023_x86_64_STANDARD" })), 0, 12)}"
  helm_values = {
    hostname              = local.hostname
    image                 = local.versions["sandbox-service"]
    replicas              = 1
    filesystemRetention   = true
    checkpointStore       = "s3://${aws_s3_bucket.filesystems.id}/sandbox-filesystems"
    workerEnv             = [{ name = "AWS_REGION", value = data.aws_region.current.region }]
    workerNodeReaderGroup = "braintrust:sandbox-worker-node-readers"
    gitResources          = true
    prewarmTemplates = [{
      image                = local.versions["sandbox-image"]
      resources            = { vcpu_count = var.sandbox_vcpu_count, memory_mib = var.sandbox_memory_mib }
      mounts               = []
      durable_file_systems = []
      policy               = { networking = { type = "disabled" }, credentials = [] }
      default_workdir      = "/home/exo/workspace"
    }]
    workerNodeSelector = { "braintrust.io/worker-revision" = local.worker_revision }
    externalDns = {
      enabled  = true
      provider = "aws"
      extraArgs = [
        "--aws-zone-type=private",
        "--zone-id-filter=${aws_route53_zone.sandbox.zone_id}",
        "--txt-owner-id=${local.cluster_name}",
      ]
      env = [{ name = "AWS_REGION", value = data.aws_region.current.region }]
    }
    nodeAutoscaler = {
      enabled   = true
      extraArgs = ["--cloud-provider=aws"]
      env       = [{ name = "AWS_REGION", value = data.aws_region.current.region }]
    }
  }
}

data "aws_region" "current" {}
data "aws_partition" "current" {}
data "aws_caller_identity" "current" {}

data "aws_subnet" "private" {
  for_each = { for index, id in var.private_subnet_ids : tostring(index) => id }
  id       = each.value

  lifecycle {
    postcondition {
      condition     = self.vpc_id == var.vpc_id
      error_message = "Every Sandbox Service subnet must belong to the main data-plane VPC."
    }
  }
}

resource "aws_cloudwatch_log_group" "cluster" {
  name              = "/aws/eks/${local.cluster_name}/cluster"
  retention_in_days = var.log_retention_days
  tags              = local.common_tags
}

resource "aws_eks_cluster" "sandbox" {
  name     = local.cluster_name
  role_arn = aws_iam_role.cluster.arn
  version  = "1.35"

  access_config {
    authentication_mode                         = "API"
    bootstrap_cluster_creator_admin_permissions = false
  }
  vpc_config {
    subnet_ids              = [for subnet in data.aws_subnet.private : subnet.id]
    endpoint_private_access = true
    endpoint_public_access  = false
  }
  enabled_cluster_log_types = ["api", "audit", "authenticator"]
  tags                      = local.common_tags

  lifecycle {
    precondition {
      condition     = length(distinct([for subnet in data.aws_subnet.private : subnet.availability_zone])) == 3
      error_message = "Sandbox Service requires three private subnets in distinct availability zones."
    }
  }

  depends_on = [aws_iam_role_policy_attachment.cluster, aws_cloudwatch_log_group.cluster]
}

resource "aws_route53_zone" "sandbox" {
  name = "${var.deployment_name}.sandbox.internal"
  vpc {
    vpc_id = var.vpc_id
  }
  tags = local.common_tags
}

resource "aws_launch_template" "system" {
  name_prefix            = "${var.deployment_name}-sandbox-system-"
  vpc_security_group_ids = [aws_security_group.system.id, aws_security_group.public_egress.id]
  metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }
  tag_specifications {
    resource_type = "instance"
    tags          = merge(local.common_tags, { Name = "${var.deployment_name}-sandbox-system" })
  }
  tag_specifications {
    resource_type = "network-interface"
    tags          = merge(local.common_tags, { "cluster.k8s.amazonaws.com/name" = local.cluster_name })
  }
  tag_specifications {
    resource_type = "volume"
    tags          = local.common_tags
  }
  tags = local.common_tags
}

resource "aws_launch_template" "workers" {
  name_prefix            = "${var.deployment_name}-sandbox-worker-"
  vpc_security_group_ids = [aws_security_group.workers.id, aws_security_group.public_egress.id]
  cpu_options {
    nested_virtualization = "enabled"
  }
  metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }
  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      encrypted             = true
      volume_type           = "gp3"
      volume_size           = 40
      delete_on_termination = true
    }
  }
  user_data = base64encode(<<-MIME
    MIME-Version: 1.0
    Content-Type: multipart/mixed; boundary="SANDBOX"

    --SANDBOX
    Content-Type: application/node.eks.aws

    apiVersion: node.eks.aws/v1alpha1
    kind: NodeConfig
    spec:
      instance:
        localStorage:
          strategy: Mount
          mountPath: /var/lib/braintrust-sandboxes

    --SANDBOX
    Content-Type: text/x-shellscript; charset="us-ascii"

    #!/bin/bash
    set -euo pipefail
    echo 'kernel.io_uring_disabled=2' > /etc/sysctl.d/99-braintrust-sandbox.conf
    sysctl -p /etc/sysctl.d/99-braintrust-sandbox.conf
    mkdir -p /run/netns
    modprobe kvm_intel
    test -c /dev/kvm
    --SANDBOX--
  MIME
  )
  tag_specifications {
    resource_type = "instance"
    tags = merge(local.common_tags, {
      Name                                = "${var.deployment_name}-sandbox-worker"
      "braintrust:sandbox-instance-types" = join(",", var.instance_types)
    })
  }
  tag_specifications {
    resource_type = "network-interface"
    tags          = merge(local.common_tags, { "cluster.k8s.amazonaws.com/name" = local.cluster_name })
  }
  tag_specifications {
    resource_type = "volume"
    tags          = local.common_tags
  }
  tags = local.common_tags
}

resource "aws_eks_node_group" "system" {
  cluster_name    = aws_eks_cluster.sandbox.name
  node_role_arn   = aws_iam_role.nodes.arn
  subnet_ids      = var.private_subnet_ids
  ami_type        = "AL2023_x86_64_STANDARD"
  instance_types  = ["t3.medium"]
  node_group_name = "sandbox-system"
  launch_template {
    id      = aws_launch_template.system.id
    version = aws_launch_template.system.latest_version
  }
  labels = { "braintrust.io/workload" = "sandbox-system" }
  scaling_config {
    min_size     = 1
    max_size     = 1
    desired_size = 1
  }
  tags = local.common_tags
  depends_on = [
    aws_iam_role_policy_attachment.nodes,
    aws_iam_role_policy.cni,
    aws_iam_role_policy.public_registry,
    aws_vpc_security_group_ingress_rule.cluster_from_nodes,
    aws_vpc_security_group_ingress_rule.system_dns,
    aws_vpc_security_group_egress_rule.system_dns,
  ]
}

# Terraform owns the complete fleet. Replacing a pool can reset its sandboxes;
# there are no retained node groups outside Terraform state.
resource "aws_eks_node_group" "workers" {
  cluster_name    = aws_eks_cluster.sandbox.name
  node_group_name = "sandbox-${local.worker_revision}"
  node_role_arn   = aws_iam_role.nodes.arn
  subnet_ids      = var.private_subnet_ids
  ami_type        = "AL2023_x86_64_STANDARD"
  instance_types  = var.instance_types
  launch_template {
    id      = aws_launch_template.workers.id
    version = aws_launch_template.workers.latest_version
  }
  labels = {
    "braintrust.io/workload"        = "sandbox-service"
    "braintrust.io/worker-revision" = local.worker_revision
  }
  taint {
    key    = "braintrust.io/sandbox"
    value  = "true"
    effect = "NO_SCHEDULE"
  }
  scaling_config {
    min_size     = 1
    max_size     = 401
    desired_size = 1
  }
  update_config {
    max_unavailable = 1
  }
  tags = local.common_tags
  lifecycle {
    create_before_destroy = true
    ignore_changes        = [scaling_config[0].desired_size]
  }
  depends_on = [
    aws_iam_role_policy_attachment.nodes,
    aws_iam_role_policy.cni,
    aws_iam_role_policy.public_registry,
    aws_eks_addon.vpc_cni,
    aws_vpc_security_group_ingress_rule.cluster_from_nodes,
    aws_vpc_security_group_egress_rule.nodes_to_cluster,
    aws_vpc_security_group_ingress_rule.system_dns,
    aws_vpc_security_group_egress_rule.worker_dns,
    aws_vpc_security_group_egress_rule.workers_public,
    aws_vpc_security_group_egress_rule.additional_public,
  ]
}

resource "aws_eks_addon" "pod_identity" {
  cluster_name = aws_eks_cluster.sandbox.name
  addon_name   = "eks-pod-identity-agent"
  tags         = local.common_tags
  depends_on   = [aws_eks_node_group.system]
}

resource "aws_eks_pod_identity_association" "dns" {
  cluster_name    = aws_eks_cluster.sandbox.name
  namespace       = local.namespace
  service_account = "external-dns"
  role_arn        = aws_iam_role.dns.arn
  tags            = local.common_tags
  depends_on      = [aws_eks_addon.pod_identity]
}

resource "aws_eks_pod_identity_association" "autoscaler" {
  cluster_name    = aws_eks_cluster.sandbox.name
  namespace       = local.namespace
  service_account = "sandbox-node-autoscaler"
  role_arn        = aws_iam_role.autoscaler.arn
  tags            = local.common_tags
  depends_on      = [aws_eks_addon.pod_identity]
}


resource "aws_eks_addon" "vpc_cni" {
  cluster_name                = aws_eks_cluster.sandbox.name
  addon_name                  = "vpc-cni"
  addon_version               = "v1.22.4-eksbuild.3"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  configuration_values        = jsonencode({ env = { WARM_IP_TARGET = "2" } })
  tags                        = local.common_tags
  depends_on                  = [aws_eks_node_group.system]
}

resource "aws_eks_pod_identity_association" "filesystems" {
  cluster_name    = aws_eks_cluster.sandbox.name
  namespace       = local.namespace
  service_account = "sandbox-service"
  role_arn        = aws_iam_role.filesystems.arn
  tags            = local.common_tags
  depends_on      = [aws_eks_addon.pod_identity]
}
