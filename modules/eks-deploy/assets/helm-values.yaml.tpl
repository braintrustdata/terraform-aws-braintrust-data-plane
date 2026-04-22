global:
  orgName: "${org_name}"
  # Namespace is pre-created by Terraform (kubernetes_namespace.braintrust).
  # createNamespace=false makes the chart use the Helm release namespace.
  createNamespace: false
  namespace: "${namespace}"

cloud: "aws"

skipPgForBrainstoreObjects: "${skip_pg}"
brainstoreWalFooterVersion: "${wal_footer_version}"

objectStorage:
  aws:
    brainstoreBucket: "${brainstore_bucket}"
    responseBucket: "${response_bucket}"
    codeBundleBucket: "${code_bundle_bucket}"

api:
  # Expose via an internal NLB that adopts the Terraform-pre-created LB.
  # `aws-load-balancer-name` tells the Load Balancer Controller to reconcile
  # the existing NLB (already wired into the CloudFront VPC Origin) instead
  # of creating a new one.
  service:
    type: LoadBalancer
  annotations:
    service:
      service.beta.kubernetes.io/aws-load-balancer-scheme: "internal"
      service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
      service.beta.kubernetes.io/aws-load-balancer-security-groups: "${nlb_sg_id}"
      service.beta.kubernetes.io/aws-load-balancer-name: "${nlb_name}"
  serviceAccount:
    awsRoleArn: "${api_role_arn}"

brainstore:
  serviceAccount:
    awsRoleArn: "${brainstore_role_arn}"

# Replicas, resources, image tags, probes, locksBackend: all left to chart
# defaults in values.yaml (production-sized). Override via TF variable
# `eks_helm_chart_extra_values` to scale down for sandbox deployments.
