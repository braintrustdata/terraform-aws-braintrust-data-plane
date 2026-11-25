locals {
  iam_tags = merge(local.common_tags, { BraintrustIAMOwner = "braintrust" })
  common_tags = merge(var.custom_tags, {
    BraintrustDeploymentName = var.deployment_name
  })
  release_template = yamldecode(data.http.release.response_body)
  release_helm_template = try(
    local.release_template.Outputs.SandboxServiceHelmValues.Value["Fn::Sub"][0],
    local.release_template.Outputs.SandboxServiceHelmValues.Value["Fn::Sub"],
  )
  # Only the image pins are used. Neutralize CloudFormation deployment tokens
  # (including unquoted numeric parameters) before decoding the published JSON.
  release_helm_values = jsondecode(replace(local.release_helm_template, "/\\$\\{[^}]+\\}/", "null"))
  release_chart       = regex("^https://([^.]+)\\.s3[^/]*/(.+)$", local.release_template.Outputs.SandboxServiceChartUrl.Value)
  release_bootstrap   = regex("^s3://([^/]+)/(.+)$", local.release_template.Resources.SandboxServiceReleaseFunction.Properties.CodeUri)
  versions = {
    sandbox-service  = local.release_helm_values.image
    sandbox-image    = local.release_helm_values.prewarmTemplates[0].image
    chart-key        = local.release_chart[1]
    bootstrap-key    = local.release_bootstrap[1]
    bootstrap-sha256 = local.release_template.Resources.SandboxServiceRelease.Properties.ProviderVersion
  }
  cluster_name      = "${var.deployment_name}-sandbox"
  namespace         = "braintrust-sandbox"
  hostname          = "nodes.${var.deployment_name}.sandbox.internal"
  artifact_bucket   = "braintrust-cf-${data.aws_region.current.region}"
  stack_name        = coalesce(var.stack_name, "${var.deployment_name}-sandbox-service")
  stack_arn_pattern = "arn:${data.aws_partition.current.partition}:cloudformation:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:stack/${local.stack_name}/*"
  worker_revision   = "${aws_launch_template.workers.id}-${aws_launch_template.workers.latest_version}-${substr(sha256(jsonencode({ version = aws_eks_cluster.sandbox.version, instance_types = var.instance_types, subnet_ids = var.private_subnet_ids, ami_type = "AL2023_x86_64_STANDARD" })), 0, 12)}"
  helm_values = {
    hostname              = local.hostname
    image                 = local.versions["sandbox-service"]
    replicas              = 1
    filesystemRetention   = true
    checkpointStore       = "s3://${var.checkpoint_bucket_id}/sandbox-filesystems"
    workerEnv             = [{ name = "AWS_REGION", value = data.aws_region.current.region }]
    workerNodeReaderGroup = "braintrust:sandbox-worker-node-readers"
    gitResources          = true
    env = [
      { name = "BRAINSTORE_LICENSE_KEY", valueFrom = { secretKeyRef = { name = "sandbox-telemetry", key = "license-key" } } },
      { name = "BRAINSTORE_CONTROL_PLANE_TELEMETRY", value = join(",", [var.monitoring_telemetry, "metrics", "traces"]) },
      { name = "BRAINSTORE_PULSE_OBSERVABILITY_ONLY", value = tostring(var.internal_observability_enabled) },
      { name = "BRAINTRUST_ENV", value = var.internal_observability_enabled ? var.internal_observability_env_name : "customer" },
    ]
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

# Follow the same release tag and HTTP lookup convention as the Lambda and
# MicroVM modules, resolving all sandbox artifacts as one compatible release.
data "http" "release" {
  url = "https://${local.artifact_bucket}.s3.amazonaws.com/braintrust-${var.version_tag}.yaml"

  retry {
    attempts     = 5
    min_delay_ms = 500
    max_delay_ms = 5000
  }
  request_timeout_ms = 10000

  lifecycle {
    postcondition {
      condition = try(
        contains(split(",", yamldecode(self.response_body).Outputs.SandboxServiceBootstrapCapabilities.Value), "license-secret") &&
        contains(split(",", yamldecode(self.response_body).Outputs.SandboxServiceBootstrapCapabilities.Value), "nodegroup-cleanup"),
        false,
      )
      error_message = "Release ${var.version_tag} must include Sandbox Service license-secret delivery and retained-nodegroup cleanup. Select a compatible Loop Runtime release."
    }
    postcondition {
      condition     = self.status_code < 400
      error_message = "Failed to fetch Sandbox Service release ${var.version_tag} at ${self.url}: HTTP ${self.status_code}."
    }
    postcondition {
      condition = (
        can(yamldecode(self.response_body).Outputs.SandboxServiceChartUrl.Value) &&
        can(yamldecode(self.response_body).Outputs.SandboxServiceHelmValues.Value) &&
        can(yamldecode(self.response_body).Resources.SandboxServiceReleaseFunction.Properties.CodeUri) &&
        can(yamldecode(self.response_body).Resources.SandboxServiceRelease.Properties.ProviderVersion)
      )
      error_message = "Release ${var.version_tag} does not publish the required Sandbox Service artifacts."
    }
  }
}

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
    aws_iam_role_policy.inspector,
    aws_vpc_security_group_ingress_rule.cluster_from_nodes,
    aws_vpc_security_group_ingress_rule.system_dns,
    aws_vpc_security_group_egress_rule.system_dns,
  ]
}

resource "aws_eks_access_entry" "operator" {
  count         = var.operator_role_arn == null ? 0 : 1
  cluster_name  = aws_eks_cluster.sandbox.name
  principal_arn = var.operator_role_arn
  type          = "STANDARD"
  tags          = local.common_tags
}

resource "aws_eks_access_policy_association" "operator" {
  count         = var.operator_role_arn == null ? 0 : 1
  cluster_name  = aws_eks_cluster.sandbox.name
  principal_arn = aws_eks_access_entry.operator[0].principal_arn
  policy_arn    = "arn:${data.aws_partition.current.partition}:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  access_scope {
    type = "cluster"
  }
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
  preserve                    = true
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
