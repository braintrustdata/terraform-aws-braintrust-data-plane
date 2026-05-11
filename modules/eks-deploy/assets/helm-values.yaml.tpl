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
      # Tag LB-Controller-created resources (TargetGroup, listener) with the
      # deployment name. The TG name is controller-generated as
      # `k8s-<ns-8>-<svc-8>-<hash>` and not configurable, so for multiple
      # Braintrust deployments in one AWS account, tags are the only way
      # to disambiguate their TGs. Matches `BraintrustDeploymentName` used
      # on TF-owned resources.
      service.beta.kubernetes.io/aws-load-balancer-additional-resource-tags: "BraintrustDeploymentName=${deployment_name}"
      # Zero out target-group drain delay. Default is 300s. Observed
      # failure mode during destroy: helm uninstall → Service deletion →
      # LB Controller holds the `service.eks.amazonaws.com/resources`
      # finalizer until all TG targets are fully drained. In broken states
      # (cluster never had nodes register, failed installs), the drain
      # never actually completes because there are no registered targets
      # to drain; LB Controller still respects the default 300s wait and
      # the finalizer hangs for 5 minutes. `terraform destroy` appears
      # frozen on the helm_release until a human `kubectl patch`es the
      # finalizer away. `deregistration_delay.timeout_seconds=0` tells
      # the NLB to immediately deregister targets with no wait, letting
      # the LB Controller release the finalizer and the helm uninstall
      # complete cleanly.
      service.beta.kubernetes.io/aws-load-balancer-target-group-attributes: "deregistration_delay.timeout_seconds=0"
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
