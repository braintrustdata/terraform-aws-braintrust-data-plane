# Terraform ↔ Helm Contract

This Terraform module is paired with the Braintrust Helm chart in
[`braintrustdata/helm`](https://github.com/braintrustdata/helm). When
`create_eks_cluster = true`, the module provisions an EKS Auto Mode
cluster and related AWS infrastructure, then deploys the Helm chart on
top of it. Several names, ports, and keys are hardcoded on both sides;
this document enumerates them.

## Pinned chart compatibility

| Field | Value |
|---|---|
| Braintrust Helm chart | `oci://public.ecr.aws/braintrust/helm` |
| Tested chart version | `5.0.1` |
| Supported range | `5.x` |

`helm_chart_version` in the module has no default when `create_eks_cluster = true` — consumers must pin.

## Coupling surfaces

### Names and identifiers

| Thing | TF location | Chart location | Failure mode |
|---|---|---|---|
| API service account name `braintrust-api` | `modules/eks-deploy/variables.tf` default `api_service_account_name`; used as the Pod Identity association's `service_account` in `modules/eks-deploy/main.tf` | `api.serviceAccount.name` default in chart `values.yaml`; referenced by `api-deployment.yaml` as `serviceAccountName` | **Silent runtime**: pod starts but Pod Identity lookup finds no association for that SA name, AWS SDK calls return 403 |
| Brainstore service account name `brainstore` | `modules/eks-deploy/variables.tf` default `brainstore_service_account_name`; used as the Pod Identity association's `service_account` | `brainstore.serviceAccount.name` default in chart | Silent runtime (same as above) |
| K8s Secret name `braintrust-secrets` | `kubernetes_secret.braintrust` in `modules/eks-deploy/main.tf` | `api-deployment.yaml` and `brainstore-*-deployment.yaml` hardcode `secretKeyRef.name: braintrust-secrets` | Pod fails to start: `CreateContainerConfigError` |
| Secret keys `PG_URL`, `REDIS_URL`, `FUNCTION_SECRET_KEY`, `BRAINSTORE_LICENSE_KEY` | `data = { ... }` in `kubernetes_secret.braintrust` | Referenced by name in chart deployment templates | Pod start-time failure (missing env var) |
| Namespace | `var.eks_namespace` → `kubernetes_namespace.braintrust` in `modules/eks-deploy/main.tf` + passed as template `namespace` var | `global.namespace` (used in configmap to build `BRAINSTORE_*_URL`); runtime namespace resolved via `braintrust.namespace` helper to `.Release.Namespace` when `createNamespace: false` | Pods run in wrong namespace; intra-cluster DNS fails |
| Brainstore NodePool label `braintrust.dev/node-pool: brainstore` | `kubernetes_manifest.brainstore_nodepool` in `modules/eks-deploy/main.tf`; referenced via `nodeSelector` on the three Brainstore components in `helm-values.yaml.tpl` | Chart passes `nodeSelector` through to pod spec unchanged | Brainstore pods stay Pending (no node matches) |

### Network / ports

| Thing | TF location | Chart location | Failure mode |
|---|---|---|---|
| API port `8000` | `aws_cloudfront_vpc_origin.api.http_port` in `modules/eks-cluster/cloudfront.tf`; NLB target port implicit via the LB Controller | `api.service.port` default `8000`; `api-deployment.yaml` containerPort | **Silent at deploy**: CloudFront → NLB → node NodePort path dead |
| NodePort range `30000-32767` | `aws_vpc_security_group_ingress_rule.nodes_from_nlb` in `modules/eks-cluster/networking.tf` | Kubernetes kube-apiserver default | K8s project default would have to change — very low risk |
| Pre-created NLB adopted via `service.beta.kubernetes.io/aws-load-balancer-name` | `aws_lb.api.name` in `modules/eks-cluster/networking.tf` (exposed as the root's `eks_nlb_name` output) | `api.annotations.service.*` — the Auto-Mode-managed LB Controller reads this annotation | If the chart stops passing annotations through or the controller renames `aws-load-balancer-name`, the controller creates a parallel NLB; CloudFront VPC Origin points at the orphan |
| NLB security group | `aws_security_group.nlb_cloudfront` in `modules/eks-cluster/networking.tf` (NLBs only accept SGs at creation time) | `service.beta.kubernetes.io/aws-load-balancer-security-groups` in `api.annotations.service` | Adopted NLB gets wrong SG; CloudFront can't reach it |

### Helm values schema the module writes

Template at `modules/eks-deploy/assets/helm-values.yaml.tpl`. Any of these
keys moving or renaming in the chart breaks us silently (template writes
a dead key, chart uses its default).

- `global.orgName`
- `global.createNamespace` (set to `false`)
- `global.namespace`
- `cloud` (set to `"aws"`)
- `skipPgForBrainstoreObjects`
- `brainstoreWalFooterVersion`
- `objectStorage.aws.brainstoreBucket`
- `objectStorage.aws.responseBucket`
- `objectStorage.aws.codeBundleBucket`
- `api.service.type` (set to `LoadBalancer`)
- `api.annotations.service.*` (the four NLB annotations)
- `api.serviceAccount.awsRoleArn`
- `brainstore.serviceAccount.awsRoleArn`
- `brainstore.{reader,fastreader,writer}.nodeSelector`

### Feature-flag value domains

TF validates allowed values at `terraform plan` time. Accepted values for
these fields must stay in sync:

- `brainstoreWalFooterVersion`: TF allows `""`, `"v1"`, `"v2"`, `"v3"`. When the chart adds support for a new version, coordinate updating TF's validation.
- `skipPgForBrainstoreObjects`: TF allows `""`, `"all"`, `"include:…"`, `"exclude:…"`. Chart passes through unchanged.

### Pod Identity vs IRSA

This module uses **EKS Pod Identity** (not IRSA) to give the API and
Brainstore pods AWS credentials, because Auto Mode ships the Pod Identity
Agent built-in. Mechanics:

- `services_common` builds an IAM trust policy with `pods.eks.amazonaws.com` as the principal, scoped by session tags (`aws:RequestTag/eks-cluster-arn`, `aws:RequestTag/kubernetes-namespace`) to this specific cluster and namespace.
- `modules/eks-deploy/` creates `aws_eks_pod_identity_association` resources binding `(cluster, namespace, service-account)` to the IAM role.

The chart's api/brainstore service-account templates still render an
`eks.amazonaws.com/role-arn: <awsRoleArn>` annotation (the IRSA path).
That's harmless here — AWS SDK credential resolution checks
`AWS_CONTAINER_CREDENTIALS_FULL_URI` (Pod Identity) before
`AWS_WEB_IDENTITY_TOKEN_FILE` (IRSA), so Pod Identity wins and IRSA is
never consulted.

### Assumptions baked into the contract

- **EKS mode assumes a fast reader is always deployed.** The chart defaults `brainstore.fastreader.replicas = 2` and unconditionally emits `BRAINSTORE_FAST_READER_URL` + `BRAINSTORE_FAST_READER_QUERY_SOURCES` from `api-configmap.yaml`, so the API always believes fast readers exist. Users who scale `eks_brainstore_fastreader_helm.replicas` to 0 opt out of this contract and own the resulting query failures.
- **Brainstore nodes are NVMe-backed.** The custom NodePool constrains Karpenter to the `c8gd` / `c7gd` / `m7gd` families by default (configurable via `eks_brainstore_nodepool_instance_families`). Brainstore caches data to an `emptyDir` volume on node-local storage; an EBS-backed fallback would be functional but much slower.

## Checklists

### Changing this module

- If the change touches any row of a table above, open a matching issue/PR in `braintrustdata/helm`.
- If you rename a service-account name or the secret name, update both the Pod Identity association and the chart values / secret name in lockstep.

### Changing the Helm chart

- Renaming any `.Values.*` key listed in "Helm values schema" → file an issue here to update `helm-values.yaml.tpl`.
- Renaming `api.serviceAccount.name` or `brainstore.serviceAccount.name` defaults → Pod Identity associations in TF use these as the `service_account` selector; will silently break without a coordinated TF change.
- Changing the API service port default away from `8000` → CloudFront VPC Origin and NLB SG in TF expect 8000; add a TF variable for port first.
- Adding a new required secret key → TF must populate it in `kubernetes_secret.braintrust`. Coordinate.

### Bumping the chart version used in the example

- Diff `values.yaml` between the old and new chart versions; scan for any key in the "Helm values schema" list above.
- `helm template` the new chart with this module's rendered values and grep for the hardcoded names: `braintrust-api`, `brainstore`, `braintrust-secrets`, the four secret keys, `containerPort: 8000`.

## Future: mechanical drift detection

Manual safety net today. Planned: CI smoke test that renders `helm
template` with TF-shaped fixture values and asserts the contract, plus a
symmetric test in the helm repo.
