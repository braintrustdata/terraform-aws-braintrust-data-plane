# The Helm provider authenticates as the same IAM principal as the AWS provider.
# Normalize an assumed-role session to its underlying IAM role for EKS access.
data "aws_iam_session_context" "installer" {
  arn = data.aws_caller_identity.current.arn
}

resource "aws_eks_access_entry" "installer" {
  cluster_name  = aws_eks_cluster.sandbox.name
  principal_arn = data.aws_iam_session_context.installer.issuer_arn
  type          = "STANDARD"
  tags          = local.common_tags
}

resource "aws_eks_access_policy_association" "installer" {
  cluster_name  = aws_eks_cluster.sandbox.name
  principal_arn = aws_eks_access_entry.installer.principal_arn
  policy_arn    = "arn:${data.aws_partition.current.partition}:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  access_scope {
    type = "cluster"
  }
}

# Read version metadata only. Certificate and private-key values stay out of
# Terraform and Helm state, including when a bundle is rotated.
data "aws_secretsmanager_secret_versions" "tls" {
  for_each = {
    server = var.server_tls_secret_arn
    client = var.client_tls_secret_arn
  }
  secret_id = each.value
  lifecycle {
    postcondition {
      condition     = length([for version in self.versions : version.version_id if contains(version.version_stages, "AWSCURRENT")]) == 1
      error_message = "Each Sandbox Service TLS secret must have one populated AWSCURRENT version."
    }
  }
}

locals {
  tls_versions = {
    for purpose, secret in data.aws_secretsmanager_secret_versions.tls : purpose => one([
      for version in secret.versions : version.version_id
      if contains(version.version_stages, "AWSCURRENT")
    ])
  }
}

resource "aws_iam_role" "tls" {
  name                 = "${var.deployment_name}-sandbox-tls"
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
        "aws:RequestTag/kubernetes-service-account" = "sandbox-external-secrets"
      } }
    }]
  })
  tags = local.iam_tags
}

resource "aws_iam_role_policy" "tls" {
  name = "sandbox-tls-bundles"
  role = aws_iam_role.tls.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat([{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
      Resource = [var.server_tls_secret_arn, var.client_tls_secret_arn]
      }], var.tls_kms_key_arn == null ? [] : [{
      Effect   = "Allow"
      Action   = "kms:Decrypt"
      Resource = var.tls_kms_key_arn
      Condition = { StringEquals = {
        "kms:ViaService" = "secretsmanager.${data.aws_region.current.region}.amazonaws.com"
      } }
    }])
  })
}

resource "aws_eks_pod_identity_association" "tls" {
  cluster_name    = aws_eks_cluster.sandbox.name
  namespace       = local.namespace
  service_account = "sandbox-external-secrets"
  role_arn        = aws_iam_role.tls.arn
  tags            = local.common_tags
  depends_on      = [aws_eks_addon.pod_identity]
}

# A namespace-scoped secrets controller copies the two existing bundles into
# Kubernetes. Neither workers nor the application receive its AWS permissions.
resource "helm_release" "external_secrets" {
  name             = "sandbox-external-secrets"
  namespace        = local.namespace
  create_namespace = true
  repository       = "https://charts.external-secrets.io"
  chart            = "external-secrets"
  version          = local.versions["external-secrets-chart"]
  wait             = true
  timeout          = 600
  values = [yamlencode({
    scopedRBAC               = true
    scopedNamespace          = local.namespace
    processPushSecret        = false
    processClusterPushSecret = false
    processClusterGenerator  = false
    webhook                  = { create = false }
    certController           = { create = false }
    serviceAccount           = { name = "sandbox-external-secrets" }
    nodeSelector             = { "braintrust.io/workload" = "sandbox-system" }
    resources                = { requests = { cpu = "10m", memory = "64Mi" }, limits = { memory = "128Mi" } }
    extraEnv = [{
      name  = "AWS_SECRETSMANAGER_ENDPOINT"
      value = "https://${aws_vpc_endpoint.secrets_manager.dns_entry[0].dns_name}"
    }]
  })]
  depends_on = [
    aws_eks_access_policy_association.installer,
    aws_eks_pod_identity_association.tls,
    aws_iam_role_policy.tls,
    aws_eks_addon.vpc_cni,
    aws_vpc_security_group_ingress_rule.cluster_from_installers,
    aws_vpc_security_group_egress_rule.system_to_secrets_manager,
    aws_vpc_security_group_ingress_rule.secrets_manager_from_system,
    aws_vpc_security_group_egress_rule.nodes_to_cluster,
    aws_vpc_security_group_egress_rule.system_public,
    aws_vpc_security_group_egress_rule.additional_public,
  ]
}

resource "helm_release" "tls" {
  name      = "sandbox-tls"
  namespace = helm_release.external_secrets.namespace
  chart     = "${path.module}/tls-secrets"
  values = [yamlencode({
    region = data.aws_region.current.region
    bundles = {
      server = { arn = var.server_tls_secret_arn, version = local.tls_versions.server }
      client = { arn = var.client_tls_secret_arn, version = local.tls_versions.client }
    }
  })]
  depends_on = [helm_release.external_secrets]
}

resource "helm_release" "sandbox" {
  name      = "sandbox-service"
  namespace = helm_release.tls.namespace
  chart     = "https://${local.artifact_bucket}.s3.amazonaws.com/${local.versions["chart-key"]}"
  wait      = true
  timeout   = 600
  # Backend changes and fleet removal are hard cutovers. Skip the chart's
  # graceful-uninstall hook so an occupied sandbox does not block removal.
  disable_webhooks = true
  values           = [yamlencode(merge(local.helm_values, { tlsRevision = sha256(jsonencode(local.tls_versions)) }))]
  depends_on = [
    helm_release.tls,
    aws_eks_node_group.workers,
    aws_eks_pod_identity_association.dns,
    aws_eks_pod_identity_association.autoscaler,
    aws_eks_pod_identity_association.filesystems,
    aws_iam_role_policy.dns,
    aws_iam_role_policy.autoscaler,
    aws_iam_role_policy.filesystems,
    aws_s3_bucket_public_access_block.filesystems,
    aws_s3_bucket_server_side_encryption_configuration.filesystems,
    aws_s3_bucket_ownership_controls.filesystems,
    aws_vpc_security_group_ingress_rule.workers_from_controller,
    aws_vpc_security_group_egress_rule.controller_to_workers,
  ]
}
