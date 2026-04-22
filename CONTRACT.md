# Terraform ↔ Helm Contract

This Terraform module is paired with the Braintrust Helm chart in
[`braintrustdata/helm`](https://github.com/braintrustdata/helm). When
`create_eks_cluster = true` (EKS deployment mode), the module provisions
AWS infrastructure that the Helm chart expects to consume, and the Helm
release in turn must match a set of names, ports, and keys this module
hardcodes into IAM trust policies and security groups.

The coupling surface is small, but **several items fail silently at pod
runtime, not at `terraform apply`**. This document enumerates them so
that a PR to either side can check it hasn't broken the other.

## Pinned chart compatibility

| Field | Value |
|---|---|
| Braintrust Helm chart | `oci://public.ecr.aws/braintrust/helm` |
| Tested chart version | `5.0.1` |
| Supported range | `5.x` (no hard validation today — revisit when 6.x ships) |

The `helm_chart_version` variable in `examples/braintrust-data-plane-eks/`
has no default — consumers must pin.

## Coupling surfaces

Anything the module *writes into the chart values* OR *trusts the chart
to name* is listed here. If you change either side, audit this list.

### Names and identifiers

| Thing | TF location | Chart location | Failure mode |
|---|---|---|---|
| API service account name `braintrust-api` | IRSA `sub` claim in API handler role trust policy (computed in `modules/eks-cluster/iam.tf` `locals.api_iam_trust_policy`, with SA name from `var.api_service_account_name`) | `api.serviceAccount.name` default in chart `values.yaml` | **Silent runtime**: pod starts, `AssumeRoleWithWebIdentity` is rejected, every AWS SDK call returns 403 |
| Brainstore service account name `brainstore` | IRSA `sub` claim in Brainstore role trust policy (computed in `modules/eks-cluster/iam.tf` `locals.brainstore_iam_trust_policy`, with SA name from `var.brainstore_service_account_name`) | `brainstore.serviceAccount.name` default | Silent runtime (same as above) |
| LB Controller service account `kube-system:aws-load-balancer-controller` | `aws_iam_role.lb_controller` trust policy in `modules/eks-cluster/iam.tf` | AWS LB Controller helm chart (upstream, not ours) | LB Controller fails to create NLB targets; API service stays unreachable |
| K8s Secret name `braintrust-secrets` | `kubernetes_secret.braintrust` in `modules/eks-deploy/main.tf` | `api-deployment.yaml` and `brainstore-*-deployment.yaml` hardcode `secretKeyRef.name: braintrust-secrets` | Pod fails to start: `CreateContainerConfigError` |
| Secret keys `PG_URL`, `REDIS_URL`, `FUNCTION_SECRET_KEY`, `BRAINSTORE_LICENSE_KEY` | `data = { ... }` in `kubernetes_secret.braintrust` (`modules/eks-deploy/main.tf`) | Referenced in chart deployment templates | Pod fails to start (missing env var key) |
| Namespace | `var.eks_namespace` → `kubernetes_namespace.braintrust` in `modules/eks-deploy/main.tf` + passed as template `namespace` var | `global.namespace` (used in configmap to build `BRAINSTORE_*_URL`); runtime namespace resolved via `braintrust.namespace` helper to `.Release.Namespace` when `createNamespace: false` | Pods run in wrong namespace; intra-cluster DNS fails |

### Network / ports

| Thing | TF location | Chart location | Failure mode |
|---|---|---|---|
| API service port `8000` | `aws_cloudfront_vpc_origin.api.http_port` in `modules/eks-cluster/cloudfront.tf`, NLB target port implicit via LB Controller | `api.service.port` default `8000`; `api-deployment.yaml` containerPort | **Silent at deploy**: CloudFront → NLB → node NodePort path dead |
| NodePort range `30000-32767` | `aws_vpc_security_group_ingress_rule.eks_nodes_from_nlb` in `modules/eks-cluster/networking.tf` | Kubernetes kube-apiserver default (outside our control) | Would require K8s project default change — very low risk |
| Pre-created NLB adopted by chart via `service.beta.kubernetes.io/aws-load-balancer-name` | `aws_lb.api.name` in `modules/eks-cluster/networking.tf` (exposed as the root's `eks_nlb_name` output) | `api.annotations.service.*` — controller reads this annotation | If chart renames the annotation or consumer unsets it, the controller creates a parallel NLB; CloudFront VPC Origin points at the orphan |
| NLB security group | `aws_security_group.nlb_cloudfront` in `modules/eks-cluster/networking.tf` (NLBs only accept SGs at creation; cannot be added later) | `service.beta.kubernetes.io/aws-load-balancer-security-groups` in `api.annotations.service` | Adopted NLB gets wrong SG; CloudFront can't reach it |

### Helm values schema written by the module template

The template lives at `modules/eks-deploy/assets/helm-values.yaml.tpl`.
Any of these keys moving or renaming in the chart breaks us silently
(the template writes a dead key, the chart uses its own default).

- `global.orgName`
- `global.createNamespace`
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

### Feature-flag value domains

- `brainstoreWalFooterVersion` — TF validation allows `""`, `"v1"`, `"v2"`, `"v3"` (see `variables.tf`). Chart must accept the same set; when the chart adds a new version, TF validation needs updating.
- `skipPgForBrainstoreObjects` — TF allows `""`, `"all"`, `"include:…"`, `"exclude:…"`. Chart passes through unchanged.

### Assumptions baked into the contract

- **EKS mode assumes a fast reader is always deployed.** The chart defaults `brainstore.fastreader.replicas = 2` and unconditionally emits `BRAINSTORE_FAST_READER_URL` + `BRAINSTORE_FAST_READER_QUERY_SOURCES` from `api-configmap.yaml`, so the API always believes fast readers are available. This differs from EC2 Brainstore mode where `brainstore_fast_reader_instance_count = 0` is a supported "disabled" state (the services module conditionally omits the env vars). In EKS mode we intentionally do not support the 0-replicas case — users who scale `eks_brainstore_fastreader_helm.replicas` to 0 opt out of this contract and own the resulting query failures.

## Checklist: making a change

### Changing the TF module

- If the change touches any row of a table above, open a matching issue/PR in `braintrustdata/helm`.
- Regenerate `helm-values.yaml.tpl` and confirm every key still exists in the chart's `values.yaml`.
- If you rename a service-account name or secret, update both the IRSA trust policy *and* the kubernetes_secret / chart values in the example.

### Changing the Helm chart

- If you rename any `.Values.*` key listed in the "Helm values schema" section, file an issue here to update `helm-values.yaml.tpl`.
- If you rename an SA (`api.serviceAccount.name` or `brainstore.serviceAccount.name`) or change the hardcoded secret name in a deployment template, this module's IRSA trust policy breaks silently — file a coordinated PR.
- If you change the API service port default away from 8000, ship a matching TF variable for `eks_api_service_port` or coordinate a default bump.
- If you want to support `fastreader.replicas = 0` in EKS mode (parity with EC2's `brainstore_fast_reader_instance_count = 0`), gate the `BRAINSTORE_FAST_READER_URL` configmap entry on `replicas > 0` first, then update the assumption in this doc.

### Bumping the chart version used in the example

- Diff the chart's `values.yaml` between versions, scan for any key listed above.
- Run `helm template` locally with this module's rendered values and grep for the hardcoded names/ports/keys listed in the tables.

## Future: mechanical drift detection

This document is a manual safety net. See `memory` notes for deferred
ideas: CI smoke tests that render `helm template` with TF-shaped values
and assert the contract, plus a symmetric test in the helm repo.
