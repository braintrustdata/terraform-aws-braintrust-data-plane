## Kubernetes namespace for Braintrust workloads.
resource "kubernetes_namespace" "braintrust" {
  metadata {
    name = var.namespace
  }
}

## Runtime credentials consumed by the chart's deployment templates.
## Name (`braintrust-secrets`) and keys are hardcoded by the chart — see
## CONTRACT.md.
resource "random_password" "function_secret" {
  length  = 32
  special = false
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
    FUNCTION_SECRET_KEY    = random_password.function_secret.result
  }
  depends_on = [kubernetes_namespace.braintrust]
}

## Pod Identity associations: bind K8s service account -> AWS IAM role.
## Auto Mode ships the Pod Identity Agent preinstalled, so no helm release
## or addon is needed. The IAM roles themselves are created by
## services_common (at the parent module level) with Pod Identity trust.
resource "aws_eks_pod_identity_association" "api" {
  cluster_name    = var.cluster_name
  namespace       = var.namespace
  service_account = var.api_service_account_name
  role_arn        = var.api_handler_role_arn
}

resource "aws_eks_pod_identity_association" "brainstore" {
  cluster_name    = var.cluster_name
  namespace       = var.namespace
  service_account = var.brainstore_service_account_name
  role_arn        = var.brainstore_iam_role_arn
}

## Custom NodeClass + NodePool for Brainstore.
##
## Brainstore caches to local NVMe SSD via emptyDir on the node, which
## requires nodes backed by instance-store-attached EC2 families (c8gd,
## c7gd, m7gd, m5d, i3, etc.). Auto Mode's default `general-purpose` pool
## doesn't constrain Karpenter to those families, so we add a custom
## NodeClass+NodePool that does, and Brainstore pods target it via the
## `braintrust.dev/node-pool: brainstore` nodeSelector in helm values.
##
## Delivered via helm_release (not kubernetes_manifest) so Terraform
## doesn't contact the cluster at plan time — kubernetes_manifest reads
## the CRD schema from the live cluster to validate, which fails on a
## fresh deploy because the cluster doesn't exist yet. Helm renders
## templates locally and applies at apply time, so a single
## `terraform apply` from an empty account works end to end.
resource "helm_release" "brainstore_nodepool" {
  name      = "brainstore-nodepool"
  chart     = "${path.module}/charts/brainstore-nodepool"
  namespace = var.namespace
  wait      = true

  # Cluster-scoped resources (NodeClass, NodePool) in a namespaced
  # release are fine with Helm; the release secret lives in the
  # namespace but the objects are cluster-wide.
  values = [
    yamlencode({
      name             = "brainstore"
      deploymentName   = var.deployment_name
      clusterName      = var.cluster_name
      nodeIamRoleName  = var.node_iam_role_name
      instanceFamilies = var.brainstore_nodepool_instance_families
    }),
  ]

  depends_on = [kubernetes_namespace.braintrust]
}

## Braintrust Helm release.
##
## Values precedence (later wins): chart defaults (values.yaml) <
## module's rendered template (names, ARNs, wiring the module owns) <
## caller's helm_values_file (replicas, resources, annotations,
## anything chart-exposed).
resource "helm_release" "braintrust" {
  name             = "braintrust"
  repository       = "oci://public.ecr.aws/braintrust/helm"
  chart            = "braintrust"
  version          = var.helm_chart_version
  namespace        = var.namespace
  create_namespace = false

  # Default helm_release timeout is 300s (5 min). With Auto Mode, a cold
  # deploy has to: provision a new Karpenter-backed Brainstore node (~2-3
  # min), pull three large Brainstore container images (~3-5 min each,
  # though pulled in parallel), then wait for all pods to pass readiness
  # probes. 5 min is usually not enough. 1200s (20 min) covers the
  # worst-case first-deploy; subsequent applies return as soon as pods
  # are Ready, well before the timeout.
  timeout = 1200

  values = compact([
    templatefile("${path.module}/assets/helm-values.yaml.tpl", {
      deployment_name     = var.deployment_name
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
    var.helm_values_file != null ? file(var.helm_values_file) : "",
  ])

  depends_on = [
    kubernetes_secret.braintrust,
    helm_release.brainstore_nodepool,
    aws_eks_pod_identity_association.api,
    aws_eks_pod_identity_association.brainstore,
  ]
}

## Destroy choreography (gated by var.prepare_for_destroy).
##
## Failure mode this avoids: when helm uninstall deletes the api Service
## during `terraform destroy`, the AWS Load Balancer Controller holds a
## `service.eks.amazonaws.com/resources` finalizer on it while it drains
## TG targets. Default deregistration_delay is 300s, and on broken-state
## clusters (no nodes ever registered, failed installs, etc.) the drain
## never resolves — Terraform appears frozen on `helm_release.braintrust`
## for many minutes until an operator manually `kubectl patch`es the
## finalizer off. The patch unblocks the destroy but interrupts the
## controller's own cleanup, leaving an orphan TargetGroup behind.
##
## Fix: force deregistration to instant *before* destroy starts.
##
##   1. `kubernetes_annotations.api_drain_zero` patches the api Service
##      with `aws-load-balancer-target-group-attributes: deregistration_delay.timeout_seconds=0`.
##      The chart's helm-values.yaml.tpl already sets this; this resource
##      is redundant on a fresh deploy but covers older charts and any
##      case where the live annotation drifted.
##
##   2. `terraform_data.api_tg_drain_zero` reaches into AWS directly and
##      sets the same attribute on every TargetGroup tagged with
##      `BraintrustDeploymentName=<deployment_name>`. Faster path than
##      waiting for LBC to reconcile from the annotation, and works even
##      if the chart's annotation never propagated.
##
## With drain wait at zero, the LB Controller releases its finalizer
## instantly during destroy, deletes its own TG, and helm uninstall
## completes cleanly — no kubectl patching, no orphan TGs.
data "aws_region" "current" {}

resource "kubernetes_annotations" "api_drain_zero" {
  count = var.prepare_for_destroy ? 1 : 0

  api_version = "v1"
  kind        = "Service"
  metadata {
    name      = "braintrust-api"
    namespace = var.namespace
  }
  annotations = {
    "service.beta.kubernetes.io/aws-load-balancer-target-group-attributes" = "deregistration_delay.timeout_seconds=0"
  }
  force = true

  depends_on = [helm_release.braintrust]
}

resource "terraform_data" "api_tg_drain_zero" {
  count = var.prepare_for_destroy ? 1 : 0

  triggers_replace = {
    deployment_name = var.deployment_name
    region          = data.aws_region.current.region
    # timestamp() forces a re-run on every apply while the toggle is
    # enabled, so flipping it true and applying always results in the
    # AWS-side attribute change being reasserted.
    apply_marker = timestamp()
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -u
      DN='${var.deployment_name}'
      REG='${data.aws_region.current.region}'

      TG_ARNS=$(aws --region "$REG" resourcegroupstaggingapi get-resources \
        --resource-type-filters elasticloadbalancing:targetgroup \
        --tag-filters "Key=BraintrustDeploymentName,Values=$DN" \
        --query 'ResourceTagMappingList[].ResourceARN' --output text)

      if [ -z "$TG_ARNS" ]; then
        echo "prepare_for_destroy: no TargetGroups tagged BraintrustDeploymentName=$DN (controller may not have created one yet — that's fine; helm uninstall will be a no-op for the Service either way)"
        exit 0
      fi

      for TG_ARN in $TG_ARNS; do
        echo "prepare_for_destroy: zeroing deregistration_delay on $TG_ARN"
        aws --region "$REG" elbv2 modify-target-group-attributes \
          --target-group-arn "$TG_ARN" \
          --attributes Key=deregistration_delay.timeout_seconds,Value=0 \
          >/dev/null
      done
    EOT
  }

  depends_on = [helm_release.braintrust]
}
