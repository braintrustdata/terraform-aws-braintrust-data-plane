# Braintrust Data Plane On EKS Auto Mode

This is the full one-click EKS Auto Mode example.

Terraform creates:

- the Braintrust AWS data plane resources
- the EKS cluster
- the CloudFront edge and private NLB
- the Kubernetes bootstrap resources
- the AWS Load Balancer Controller
- the Brainstore Auto Mode NodeClass and NodePool resources
- the Braintrust Helm release

If you want Terraform-managed node groups but a manual app install, use
[`../eks-terraform-managed/`](../eks-terraform-managed/).

## Required Inputs

- `braintrust_org_name`
- `brainstore_license_key`
- `eks_helm_chart_version`

## Apply

```bash
terraform init
terraform apply
```

After apply, register the API URL in the Braintrust dashboard:

```bash
terraform output -raw api_url
```

This example leaves `eks_enable_cloudfront_nlb_ingress = true`, so Terraform
also provisions the module-managed CloudFront + private NLB ingress path.

## Custom Domain

To use your own hostname, provide:

- `custom_domain`
- `custom_certificate_arn`

The ACM certificate must live in `us-east-1`. After apply, create a DNS alias
to:

```bash
terraform output -raw cloudfront_distribution_domain_name
terraform output -raw cloudfront_distribution_hosted_zone_id
```

## Connect To The Cluster

```bash
$(terraform output -raw connect_to_cluster)
kubectl get pods -n "$(terraform output -raw eks_namespace)"
```
