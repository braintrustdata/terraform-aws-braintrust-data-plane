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
  # `aws-load-balancer-name` tells the Load Balancer Controller (managed by
  # EKS Auto Mode) to reconcile the existing NLB — whose ARN is already
  # wired into the CloudFront VPC Origin — instead of creating a new one.
  service:
    type: LoadBalancer
  annotations:
    service:
      service.beta.kubernetes.io/aws-load-balancer-scheme: "internal"
      service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
      service.beta.kubernetes.io/aws-load-balancer-security-groups: "${nlb_sg_id}"
      service.beta.kubernetes.io/aws-load-balancer-name: "${nlb_name}"
  serviceAccount:
    # Harmless under Pod Identity: the chart writes an IRSA-style
    # `eks.amazonaws.com/role-arn` annotation on the service account, but
    # Auto Mode's Pod Identity Agent intercepts AWS SDK credential
    # resolution before IRSA is consulted, so this annotation is unused.
    awsRoleArn: "${api_role_arn}"

brainstore:
  serviceAccount:
    awsRoleArn: "${brainstore_role_arn}"
  # Pin all three Brainstore components to the Terraform-managed NodePool,
  # which constrains nodes to NVMe-backed instance families for the cache.
  reader:
    nodeSelector:
      braintrust.dev/node-pool: brainstore
  fastreader:
    nodeSelector:
      braintrust.dev/node-pool: brainstore
  writer:
    nodeSelector:
      braintrust.dev/node-pool: brainstore
