data "aws_region" "current" {}

## Shared secret for the API's signed-function-execution feature.
## Generated once and stored in the Kubernetes Secret consumed by the chart.
resource "random_password" "function_secret" {
  length  = 32
  special = false
}

## Braintrust namespace for chart workloads.
resource "kubernetes_namespace" "braintrust" {
  metadata {
    name = var.namespace
  }
}

## Runtime credentials consumed by the chart's deployment templates.
## Secret name and keys are hardcoded by the chart (see CONTRACT.md).
resource "kubernetes_secret" "braintrust" {
  metadata {
    name      = "braintrust-secrets"
    namespace = var.namespace
  }
  data = {
    PG_URL                 = "postgresql://${var.postgres_username}:${var.postgres_password}@${var.postgres_host}:${var.postgres_port}/postgres?sslmode=require"
    REDIS_URL              = "redis://${var.redis_host}:${var.redis_port}"
    BRAINSTORE_LICENSE_KEY = var.brainstore_license_key
    FUNCTION_SECRET_KEY    = random_password.function_secret.result
  }
  depends_on = [kubernetes_namespace.braintrust]
}

## AWS Load Balancer Controller.
## Runs in kube-system; adopts the pre-created NLB when the Braintrust chart
## is released (via the aws-load-balancer-name annotation in helm-values.yaml.tpl).
resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"

  set {
    name  = "clusterName"
    value = var.cluster_name
  }
  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = var.lb_controller_role_arn
  }
  set {
    name  = "region"
    value = data.aws_region.current.region
  }
  set {
    name  = "vpcId"
    value = var.vpc_id
  }
}

## Braintrust application Helm release.
##
## Values precedence (later wins): chart defaults (values.yaml) <
## rendered template < structured overrides < raw YAML escape hatch.
resource "helm_release" "braintrust" {
  name             = "braintrust"
  repository       = "oci://public.ecr.aws/braintrust/helm"
  chart            = "braintrust"
  version          = var.helm_chart_version
  namespace        = var.namespace
  create_namespace = false

  values = compact([
    templatefile("${path.module}/assets/helm-values.yaml.tpl", {
      org_name            = var.braintrust_org_name
      namespace           = var.namespace
      brainstore_bucket   = var.brainstore_bucket_name
      response_bucket     = var.response_bucket_name
      code_bundle_bucket  = var.code_bundle_bucket_name
      brainstore_role_arn = var.brainstore_iam_role_arn
      api_role_arn        = var.api_handler_role_arn
      nlb_sg_id           = var.nlb_security_group_id
      nlb_name            = var.nlb_name
      wal_footer_version  = var.brainstore_wal_footer_version
      skip_pg             = var.skip_pg_for_brainstore_objects
    }),
    local.helm_structured_overrides_yaml,
    var.helm_chart_extra_values,
  ])

  depends_on = [
    helm_release.aws_load_balancer_controller,
    kubernetes_secret.braintrust,
  ]
}
