locals {
  common_tags = merge(var.custom_tags, {
    BraintrustDeploymentName = var.deployment_name
  })
  versions          = jsondecode(file("${path.module}/VERSIONS.json"))
  cluster_name      = "${var.deployment_name}-sandbox"
  namespace         = "braintrust-sandbox"
  hostname          = "nodes.${var.deployment_name}.sandbox.internal"
  artifact_bucket   = "braintrust-cf-${data.aws_region.current.region}"
  stack_name        = "${var.deployment_name}-sandbox-service"
  stack_arn_pattern = "arn:${data.aws_partition.current.partition}:cloudformation:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:stack/${local.stack_name}/*"
  worker_revision   = "${aws_launch_template.workers.id}-${aws_launch_template.workers.latest_version}-${substr(sha256(jsonencode({ version = aws_eks_cluster.sandbox.version, instance_types = var.instance_types })), 0, 12)}"
  helm_values = {
    hostname     = local.hostname
    image        = local.versions["sandbox-service"]
    replicas     = 1
    gitResources = true
    controller = {
      env = [{ name = "AWS_REGION", value = data.aws_region.current.region }]
    }
    loopRuntime = {
      cluster          = var.ecs_cluster_name
      service          = var.loop_runtime_service_name
      sandboxVcpuCount = var.sandbox_vcpu_count
      sandboxMemoryMib = var.sandbox_memory_mib
    }
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

  depends_on = [aws_iam_role_policy_attachment.cluster]
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
    aws_vpc_security_group_ingress_rule.cluster_from_nodes,
    aws_vpc_security_group_ingress_rule.system_dns,
    aws_vpc_security_group_egress_rule.system_dns,
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

resource "aws_eks_pod_identity_association" "controller" {
  cluster_name    = aws_eks_cluster.sandbox.name
  namespace       = local.namespace
  service_account = "sandbox-worker-controller"
  role_arn        = aws_iam_role.controller.arn
  tags            = local.common_tags
  depends_on      = [aws_eks_addon.pod_identity]
}
