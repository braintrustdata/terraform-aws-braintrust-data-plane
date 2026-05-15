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

## EKS API Endpoint Access

This example manages Kubernetes and Helm resources during the same Terraform
apply that creates the EKS cluster. If you disable the public EKS API endpoint,
the Terraform runner must be inside the VPC or on a connected network that can
reach the private endpoint, such as VPN, Direct Connect, Transit Gateway, a
VPC-attached CI runner, or an SSM-reached admin host.

For a laptop or public CI bootstrap, keep private access enabled. The example
defaults `eks_public_access_cidrs` to `["0.0.0.0/0"]` for compatibility, but
production deployments should restrict the public endpoint to explicit operator
or CI egress CIDRs:

```hcl
eks_enable_public_access = true
eks_public_access_cidrs  = ["203.0.113.10/32"]
```

For private-only production applies, run Terraform from a VPC-connected
environment and set:

```hcl
eks_enable_public_access = false
```

## EKS Access Entries

The cluster creator keeps bootstrap admin access. Add explicit long-lived human
or CI access through `eks_access_entries`; for example:

```hcl
eks_access_entries = {
  platform_admin = {
    principal_arn = "arn:aws:iam::123456789012:role/PlatformAdmin"
    policy_associations = {
      cluster_admin = {
        policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
        access_scope = {
          type = "cluster"
        }
      }
    }
  }

  support_viewer = {
    principal_arn = "arn:aws:iam::123456789012:role/BraintrustSupportViewer"
    policy_associations = {
      braintrust_logs = {
        policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSViewPolicy"
        access_scope = {
          type       = "namespace"
          namespaces = ["braintrust"]
        }
      }
    }
  }

  ci_deployer = {
    principal_arn = "arn:aws:iam::123456789012:role/BraintrustDeploy"
    policy_associations = {
      braintrust_deploy = {
        policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSEditPolicy"
        access_scope = {
          type       = "namespace"
          namespaces = ["braintrust"]
        }
      }
    }
  }
}
```

Adjust `namespaces` if you change `eks_namespace`.

## Apply

```bash
terraform init
terraform apply
```

The example sets conservative Brainstore reader / fast-reader / writer defaults so
the dedicated Auto Mode NodePools have allocatable headroom on their fixed
`4xlarge` / `8xlarge` instance sizes. Override `eks_brainstore_reader_instance_sizes`
or `eks_brainstore_writer_instance_sizes` if you need larger reader or writer nodes.
If you increase Brainstore replicas or
requests, wait for the dedicated Brainstore pods to become `Running` before
registering the API URL.

Check rollout status first:

```bash
$(terraform output -raw connect_to_cluster)
kubectl get pods -n "$(terraform output -raw eks_namespace)" -w
```

After the API and Brainstore pods are ready, register the API URL in the Braintrust dashboard:

```bash
terraform output -raw api_url
```

This example leaves `eks_enable_cloudfront_nlb_ingress = true`, so Terraform
also provisions the module-managed CloudFront + private NLB ingress path.

For production public deployments, create an AWS WAF Web ACL with the managed
rules and rate limits that match your environment, then attach it to the
module-managed CloudFront distribution:

```hcl
waf_acl_id = "arn:aws:wafv2:us-east-1:123456789012:global/webacl/braintrust/..."
```

If you need Kubernetes NetworkPolicy enforcement, add the VPC CNI network policy
configuration and NetworkPolicy manifests in your environment. This example
does not configure those policies for you.

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
