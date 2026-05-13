# Braintrust Data Plane On Terraform-Managed EKS

This example builds the AWS data plane and a Terraform-managed EKS cluster, then
stops short of installing the Braintrust application.

Terraform creates:

- the Braintrust AWS data plane resources
- the EKS cluster
- the managed node groups for system, services, and Brainstore workloads
- the IAM and cluster outputs you need for a manual follow-up install

Terraform does **not** install the Braintrust Helm release in this example.
After the cluster is up, customers can go to the Helm repository and install the
app separately using their own workflow.

This example also disables the module-managed CloudFront + private NLB ingress
path by setting `eks_enable_cloudfront_nlb_ingress = false`. That makes it the
bring-your-own-ingress example: customers are expected to install the app
separately and choose their own ingress, certificate, and DNS setup.

If you want the same Terraform-managed cluster shape but with the bundled
CloudFront/NLB edge enabled, set `eks_enable_cloudfront_nlb_ingress = true`.

If you want the app deployed in the same apply, use
[`../eks-auto-mode/`](../eks-auto-mode/).

## Required Inputs

- `braintrust_org_name`
- `brainstore_license_key`

## Apply

```bash
terraform init
terraform apply
```

After apply, connect to the cluster and follow the Braintrust Helm repository
installation flow separately. Because this example disables the module-managed
ingress, the `api_url` and CloudFront outputs stay `null` until you add your
own ingress path.

## Bundled Ingress Toggle

This example defaults to:

```hcl
eks_enable_cloudfront_nlb_ingress = false
```

If you want the module to provision the private NLB + CloudFront edge for you,
set:

```hcl
eks_enable_cloudfront_nlb_ingress = true
```

When the bundled ingress is enabled, you can optionally set:

- `custom_domain`
- `custom_certificate_arn`

The ACM certificate must live in `us-east-1`.

## Connect To The Cluster

```bash
$(terraform output -raw connect_to_cluster)
kubectl get pods -n "$(terraform output -raw eks_namespace)"
```
