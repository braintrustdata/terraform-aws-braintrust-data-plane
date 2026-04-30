# `eks-deploy` submodule

The Kubernetes + Helm layer that goes on top of an EKS Auto Mode cluster (provisioned by `eks-cluster`). Instantiated by the root module when `create_eks_cluster = true`; not intended for direct consumption.

## What this submodule owns

- `kubernetes_namespace.braintrust` — the namespace every Braintrust workload runs in
- `kubernetes_secret.braintrust-secrets` — the chart-contract secret holding `PG_URL`, `REDIS_URL`, `BRAINSTORE_LICENSE_KEY`, `FUNCTION_SECRET_KEY`. Generated from inputs; chart pods reference it by name.
- Two `aws_eks_pod_identity_association` resources binding the `braintrust-api` and `brainstore` service accounts to IAM roles
- `helm_release.brainstore_nodepool` installing an in-repo Helm chart at `charts/brainstore-nodepool/` that provisions a custom Karpenter `NodeClass` + `NodePool` for NVMe-backed Brainstore nodes
- `helm_release.braintrust` installing the Braintrust chart from `oci://public.ecr.aws/braintrust/helm`, with values rendered from `assets/helm-values.yaml.tpl` + the caller's optional `helm_values_file`

## What this submodule does not own

- The EKS cluster itself (that's `eks-cluster`)
- IAM role definitions — they come from `services_common` (shared with the non-EKS path) and are passed in via ARN
- S3 buckets — owned by `storage`; bucket names are passed in

## The in-repo `brainstore-nodepool` chart

`charts/brainstore-nodepool/` contains a tiny two-template Helm chart (NodeClass + NodePool). We use `helm_release` to install it instead of `kubernetes_manifest` because `kubernetes_manifest` reads CRD schemas from the live cluster at *plan time* — which fails on a fresh deploy before the cluster exists. Helm renders templates locally and only contacts the cluster at apply time. This is one of the two tricks that make single-apply bootstrap possible (the other is the root module exposing cluster-endpoint/CA as outputs instead of a `data.aws_eks_cluster` lookup).

The rendered NodeClass + NodePool are byte-identical to what `kubernetes_manifest` produced before the migration — verified by rendering the chart and diffing the generated YAML against the old HCL values, including the `aws:eks:cluster-name` tag-key with colons.

## Helm values precedence

`helm_release.braintrust` merges values in this order (later wins, per Helm's standard semantics):

1. Chart defaults from `values.yaml` in the upstream chart
2. Module-rendered template at `assets/helm-values.yaml.tpl` (names, ARNs, annotations wiring that only Terraform knows)
3. Caller's `helm_values_file` (optional path to a YAML file with component-level tuning like replicas, resources, annotations, probes, etc.)

This mirrors the Helm CLI's `-f base.yaml -f override.yaml` semantics.

## Customization surface

For direct consumers (the root module is the typical consumer):

- `deployment_name`, `namespace`, `cluster_name`, `nlb_name`, `nlb_security_group_id` — identity / adoption plumbing
- `api_handler_role_arn`, `brainstore_iam_role_arn` — IAM ARNs for Pod Identity
- `postgres_*`, `redis_*`, `*_bucket_name`, `brainstore_license_key` — data-plane inputs rendered into the Secret + values template
- `brainstore_nodepool_instance_families` — which EC2 families Karpenter may use for Brainstore nodes (must be NVMe-backed)
- `helm_chart_version` — Braintrust chart version to pin
- `helm_values_file` — path to a YAML file with caller overrides (null for chart defaults)

See `variables.tf` for the full list with descriptions.

## Module ↔ Chart contract

Several names, ports, and keys are hardcoded on both the module and chart sides. See [`../../CONTRACT.md`](../../CONTRACT.md) for the enumerated coupling surfaces. Do not silently rename any of: the Secret name, the Secret keys, the service-account names, the API container port, the NLB adoption annotations, or the Brainstore `nodeSelector` label.
