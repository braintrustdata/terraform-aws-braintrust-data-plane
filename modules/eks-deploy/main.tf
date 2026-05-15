data "aws_region" "current" {}

resource "kubernetes_namespace" "braintrust" {
  metadata {
    name = var.namespace
  }
}

resource "kubernetes_secret" "braintrust" {
  metadata {
    name      = "braintrust-secrets"
    namespace = var.namespace
  }

  data = {
    PG_URL                 = "postgresql://${var.postgres_username}:${var.postgres_password}@${var.postgres_host}:${var.postgres_port}/postgres?sslmode=require"
    REDIS_URL              = "redis://${var.redis_host}:${var.redis_port}"
    BRAINSTORE_LICENSE_KEY = var.brainstore_license_key
    FUNCTION_SECRET_KEY    = var.function_secret_key
  }

  type = "Opaque"

  depends_on = [kubernetes_namespace.braintrust]
}

resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = var.aws_load_balancer_controller_chart_version
  namespace  = "kube-system"

  values = [
    yamlencode({
      clusterName = var.cluster_name
      region      = data.aws_region.current.region
      vpcId       = var.vpc_id
      serviceAccount = {
        create = true
        name   = var.aws_load_balancer_controller_service_account
      }
    })
  ]
}

resource "helm_release" "brainstore_auto_mode" {
  count = var.use_auto_mode ? 1 : 0

  name             = "brainstore-auto-mode"
  chart            = "${path.module}/charts/brainstore-auto-mode"
  namespace        = var.namespace
  create_namespace = false
  wait             = false

  values = [
    yamlencode({
      nodeRoleName       = var.node_role_name
      clusterName        = var.cluster_name
      instanceFamilies   = var.brainstore_instance_families
      subnetTagKey       = "kubernetes.io/role/internal-elb"
      subnetTagValue     = "1"
      securityGroupKey   = "kubernetes.io/cluster/${var.cluster_name}"
      securityGroupValue = "owned"
      reader = {
        nodeClassName        = "brainstore-reader"
        nodePoolName         = "brainstore-reader"
        ephemeralStorageSize = "1000Gi"
        instanceSizes        = var.brainstore_reader_instance_sizes
        cpuLimit             = "80"
        memoryLimit          = "160Gi"
      }
      writer = {
        nodeClassName        = "brainstore-writer"
        nodePoolName         = "brainstore-writer"
        ephemeralStorageSize = "2000Gi"
        instanceSizes        = var.brainstore_writer_instance_sizes
        cpuLimit             = "128"
        memoryLimit          = "256Gi"
      }
    })
  ]

  depends_on = [kubernetes_namespace.braintrust]
}

resource "helm_release" "braintrust" {
  count = var.manage_braintrust_helm_release ? 1 : 0

  name             = "braintrust"
  repository       = "oci://public.ecr.aws/braintrust/helm"
  chart            = "braintrust"
  version          = var.helm_chart_version
  namespace        = var.namespace
  create_namespace = false
  timeout          = 1200
  cleanup_on_fail  = true
  wait             = false

  values = local.helm_values_documents

  depends_on = [
    helm_release.aws_load_balancer_controller,
    helm_release.brainstore_auto_mode,
    kubernetes_secret.braintrust,
  ]
}
