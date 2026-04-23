data "aws_region" "current" {}

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
## These manifests use CRDs that Auto Mode installs on the cluster, so
## kubernetes_manifest can only plan them after the cluster exists. Use
## the two-step apply described in the example README.
resource "kubernetes_manifest" "brainstore_nodeclass" {
  manifest = {
    apiVersion = "eks.amazonaws.com/v1"
    kind       = "NodeClass"
    metadata = {
      name = "brainstore"
    }
    spec = {
      role = var.node_iam_role_name
      subnetSelectorTerms = [{
        tags = {
          # Scope to this deployment's VPC — `kubernetes.io/role/internal-elb`
          # alone can match subnets in *other* VPCs (e.g. a default VPC or
          # another EKS cluster in the same region/account), which makes
          # Karpenter pick a subnet in a different VPC than our SG and fail
          # RunInstances with `Client.InvalidParameter: Security group ...
          # and subnet ... belong to different networks.`
          "kubernetes.io/role/internal-elb" = "1"
          "BraintrustDeploymentName"        = var.deployment_name
        }
      }]
      securityGroupSelectorTerms = [{
        tags = {
          "aws:eks:cluster-name" = var.cluster_name
        }
      }]
      # No custom `tags` field: Auto Mode's `AmazonEKSComputePolicy` gates
      # `ec2:CreateLaunchTemplate` on a `ForAllValues:StringLike` condition
      # that only allows the tag keys `eks:eks-cluster-name`,
      # `eks:kubernetes-node-class-name`, `eks:kubernetes-node-pool-name`,
      # and `kubernetes.io/cluster/*`. Any additional key causes the
      # controller's CreateLaunchTemplate call to fail the IAM pre-check.
      # Auto-managed `eks:*` tags are set by the controller itself;
      # we don't add anything here.
    }
  }
}

resource "kubernetes_manifest" "brainstore_nodepool" {
  manifest = {
    apiVersion = "karpenter.sh/v1"
    kind       = "NodePool"
    metadata = {
      name = "brainstore"
    }
    spec = {
      template = {
        metadata = {
          labels = {
            "braintrust.dev/node-pool" = "brainstore"
          }
        }
        spec = {
          nodeClassRef = {
            group = "eks.amazonaws.com"
            kind  = "NodeClass"
            name  = "brainstore"
          }
          requirements = [
            # Auto Mode restricts NodePool requirement keys to the domains
            # `karpenter.sh/*`, `kubernetes.io/*`, `node.kubernetes.io/*`,
            # `topology.kubernetes.io/*`, and `eks.amazonaws.com/*` — so we
            # use the Auto-Mode-specific `eks.amazonaws.com/instance-family`
            # instead of self-managed Karpenter's `karpenter.k8s.aws/instance-family`.
            {
              key      = "eks.amazonaws.com/instance-family"
              operator = "In"
              values   = var.brainstore_nodepool_instance_families
            },
            {
              key      = "kubernetes.io/arch"
              operator = "In"
              values   = ["arm64", "amd64"]
            },
            {
              key      = "karpenter.sh/capacity-type"
              operator = "In"
              values   = ["on-demand"]
            },
          ]
          # Brainstore pods are long-lived; avoid Karpenter consolidating
          # them off in the middle of serving traffic.
          terminationGracePeriod = "1h"
        }
      }
      disruption = {
        # Only replace nodes when they're empty (e.g. pod count drops to
        # zero during scale-down). No opportunistic consolidation.
        consolidationPolicy = "WhenEmpty"
        consolidateAfter    = "5m"
      }
    }
  }

  depends_on = [kubernetes_manifest.brainstore_nodeclass]
}

## Braintrust Helm release.
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
    local.helm_structured_overrides_yaml,
    var.helm_chart_extra_values,
  ])

  depends_on = [
    kubernetes_secret.braintrust,
    kubernetes_manifest.brainstore_nodepool,
    aws_eks_pod_identity_association.api,
    aws_eks_pod_identity_association.brainstore,
  ]
}
