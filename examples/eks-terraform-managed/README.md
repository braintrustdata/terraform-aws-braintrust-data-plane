# Braintrust Data Plane On Terraform-Managed EKS

This example creates the Braintrust AWS data plane and an EKS cluster with
Terraform-managed node groups, but leaves the Braintrust application install to
you.

Terraform creates:

- the Braintrust AWS data plane resources
- the EKS cluster
- the managed node groups for system, services, and Brainstore workloads
- the IAM roles, buckets, database, Redis instance, and helper outputs you need
  for a manual Helm install

Terraform does not install the Braintrust Helm release, the Cluster Autoscaler,
or an ingress controller in this example.

## What You Still Need

- A cluster autoscaler strategy if you want the EKS node groups to scale beyond
  their initial desired sizes. The example creates managed node groups with
  min/max bounds, but it does not install Cluster Autoscaler or Karpenter for
  you.
- An ingress path of your choice. This example defaults to
  `eks_enable_cloudfront_nlb_ingress = false`, so you are expected to choose
  and install your own ingress or service exposure model.

Common choices:

- an AWS Load Balancer Controller plus `Service` or `Ingress`
- an Istio gateway with the chart's `virtualService` settings
- any internal platform-specific ingress controller your team already uses

If you want the module to provision the bundled CloudFront + private NLB edge
instead, set:

```hcl
eks_enable_cloudfront_nlb_ingress = true
```

When the bundled ingress is enabled, you can also set:

- `custom_domain`
- `custom_certificate_arn`

The ACM certificate must live in `us-east-1`.

## Required Inputs

- `braintrust_org_name`
- `brainstore_license_key`

## EKS API Endpoint Access

This example creates the EKS infrastructure but does not install the Braintrust
Helm release. The Terraform infrastructure apply only needs AWS API access, but
future `kubectl` and `helm` commands must be able to reach the EKS API endpoint.

For a laptop or public CI bootstrap, keep private access enabled. The example
defaults `eks_public_access_cidrs` to `["0.0.0.0/0"]` for compatibility, but
production deployments should restrict the public endpoint to explicit operator
or CI egress CIDRs:

```hcl
eks_enable_public_access = true
eks_public_access_cidrs  = ["203.0.113.10/32"]
```

For private-only clusters, run `kubectl` and Helm from the VPC or a connected
network, such as VPN, Direct Connect, Transit Gateway, a VPC-attached CI runner,
or an SSM-reached admin host, and set:

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

If you need Kubernetes NetworkPolicy enforcement, add the VPC CNI network policy
configuration and NetworkPolicy manifests in your environment. This example
does not configure those policies for you.

## Apply

```bash
terraform init
terraform apply
```

## Connect To The Cluster

```bash
terraform output -raw connect_to_cluster | bash
kubectl get pods -n "$(terraform output -raw eks_namespace)"
```

## Create The Kubernetes Secret

This example exposes a ready-to-run secret command, but it intentionally leaves
the Brainstore license as a placeholder so you do not leak the actual license
via outputs.

```bash
terraform output -raw braintrust_secrets_command
```

Replace `<brainstore-license>` with your real Brainstore license key, then run
the command.

## Write The Base Helm Values File

```bash
terraform output -raw braintrust_write_generated_values_command | bash
```

This writes `braintrust-generated-values.yaml`, which includes:

- the Braintrust org and namespace
- S3 bucket names
- API and Brainstore IAM role ARNs
- node selectors and tolerations that match the dedicated Terraform-managed
  node groups

Create a separate `values.yaml` for your environment-specific overrides,
especially ingress and exposure settings.

Examples of what typically goes into `values.yaml`:

- your ingress or gateway configuration
- any custom hostname configuration
- service type overrides if you are not using `ClusterIP`
- resource overrides if you want something different from chart defaults

## Install The Public Braintrust Helm Chart

```bash
terraform output -raw braintrust_public_helm_command
```

That prints a command like:

```bash
helm upgrade --install braintrust \
  oci://public.ecr.aws/braintrust/helm/braintrust \
  --namespace braintrust \
  --create-namespace \
  --values ./braintrust-generated-values.yaml \
  --values ./values.yaml
```

## Useful Outputs

- `connect_to_cluster`: configure `kubectl` for the new EKS cluster
- `postgres_database_secret_arn`: Secrets Manager ARN for the database creds
- `postgres_database_address`: PostgreSQL hostname
- `postgres_database_port`: PostgreSQL port
- `redis_endpoint`: Redis hostname
- `redis_port`: Redis port
- `function_tools_secret_key`: function tools secret key
- `braintrust_secrets_command`: ready-to-edit secret creation command with a
  `<brainstore-license>` placeholder
- `braintrust_generated_values_yaml`: generated base Helm values
- `braintrust_write_generated_values_command`: writes
  `braintrust-generated-values.yaml`
- `braintrust_public_helm_command`: public OCI Helm install command
- `api_url`: stays `null` until you enable bundled ingress or add your own
  ingress path
