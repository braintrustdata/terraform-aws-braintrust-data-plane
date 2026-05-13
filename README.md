# Braintrust Terraform Module

For the latest guidance, always refer to the official Braintrust documentation:
- [Self-hosting overview](https://www.braintrust.dev/docs/admin/self-hosting)
- [Data Plane 2.0 upgrade guide](https://www.braintrust.dev/docs/admin/self-hosting/upgrade/v2)

This module is used to create the VPC, Databases, Lambdas, and associated resources for the self-hosted Braintrust data plane.

## How to use this module

To use this module, **copy the [`examples/braintrust-data-plane`](examples/braintrust-data-plane) directory to a new Terraform directory in your own repository**. Follow the instructions in the [`README.md`](examples/braintrust-data-plane/README.md) file in that directory to configure the module for your environment.

The default configuration is a large production-sized deployment. Please consider that when testing and adjust the configuration to use smaller sized resources.

If you're using a brand new AWS account for your Braintrust data plane you will need to run ./scripts/create-service-linked-roles.sh once to ensure IAM service-linked roles are created.

## Module Configuration
All module input variables and outputs are documented inline in the module's Terraform files (see `variables.tf`, `outputs.tf`, and the submodules for details).

## EKS Deployment Mode

Use `use_deployment_mode_eks = true` together with `create_eks_cluster = true` to have this module build the AWS and EKS infrastructure for a Braintrust deployment. In this mode, the root module stops at the infrastructure boundary: it creates the VPC-facing resources, database, Redis, storage, IAM, EKS cluster, node capacity, and the outputs needed by a Kubernetes deployment layer. The bundled CloudFront + private NLB ingress path is enabled by default and can be disabled with `eks_enable_cloudfront_nlb_ingress = false` if you want to bring your own ingress.

The two EKS examples show the intended compositions on top of that base:

- [`examples/eks-auto-mode`](examples/eks-auto-mode) is the one-click path. It composes the root module with `modules/eks-deploy` to create the cluster, bundled CloudFront/NLB ingress, and deploy the Braintrust app in the same apply, using EKS Auto Mode for compute.
- [`examples/eks-terraform-managed`](examples/eks-terraform-managed) is the handoff path. It creates the AWS data plane and a Terraform-managed EKS cluster with explicit node groups, disables the bundled ingress by default, and leaves the final Braintrust chart install plus ingress choice to the customer.

The older `use_deployment_mode_external_eks` variable remains supported as a deprecated alias for backwards compatibility.

If your EKS cluster is managed outside this module, use one of the external EKS examples instead:

- [`examples/braintrust-data-plane-external-eks`](examples/braintrust-data-plane-external-eks) for EKS without a quarantine VPC
- [`examples/braintrust-data-plane-external-eks-quarantine`](examples/braintrust-data-plane-external-eks-quarantine) for EKS with a quarantine VPC for user-defined functions

By default, EKS deployments with `eks_enable_cloudfront_nlb_ingress = true` use the generated CloudFront `*.cloudfront.net` hostname and the default CloudFront TLS certificate. Leave `custom_domain = null` and `custom_certificate_arn = null` for this baseline.

To use a customer-owned hostname with the bundled ingress path, set `custom_domain` and provide an ACM certificate ARN from `us-east-1` through `custom_certificate_arn`. CloudFront requires viewer certificates for custom aliases to live in `us-east-1`, even when the data plane runs in another AWS region.

The module does not create or validate the certificate for you, and it does not create DNS records automatically. The expected workflow is:

1. Request or import an ACM certificate for the exact hostname you want CloudFront to serve, in `us-east-1`.
2. Validate that certificate in ACM.
3. Set `custom_domain` and `custom_certificate_arn` on the module.
4. Apply Terraform so the CloudFront distribution is updated with the alias and viewer certificate.
5. Create a DNS alias record for `custom_domain` that points at the module outputs `cloudfront_distribution_domain_name` and `cloudfront_distribution_hosted_zone_id`.
6. Register the resulting `api_url` output in the Braintrust dashboard.

If you leave both values null, the module continues to use the generated CloudFront hostname and default certificate. If you set `custom_domain`, you should also set `custom_certificate_arn`; CloudFront will reject a custom alias without a matching `us-east-1` ACM certificate.

If you set `eks_enable_cloudfront_nlb_ingress = false`, the module does not create the private NLB, CloudFront distribution, or related CloudFront outputs. In that mode, `api_url` is also null until you provide your own ingress path.

`waf_acl_id` is optional in both the Lambda/API Gateway and EKS/CloudFront paths. If set, the module attaches your existing WAF Web ACL to the CloudFront distribution; if not set, no WAF is attached.

## Useful scripts

### dump-logs.sh
This script will dump the logs for the given deployment and services to the `logs-<deployment_name>` directory. This is useful for debugging issues with the data plane and sharing with the Braintrust team.

```
# ./dump-logs.sh <deployment_name> [--minutes N] [--service <svc1,svc2,...|all>]

./dump-logs.sh bt-sandbox
Fetching logs for the last 60 minutes for APIHandler...
Fetching logs for the last 60 minutes for brainstore...
✅ Saved logs for brainstore to logs-bt-sandbox/brainstore.log
✅ Saved logs for APIHandler to logs-bt-sandbox/APIHandler.log
```

### create-service-linked-roles.sh
Required for new AWS accounts to ensure IAM service-linked roles are created.
```
./scripts/create-service-linked-roles.sh
```

### VPCs

This module creates two VPCs by default:
- `main` VPC: This is the main VPC that contains the Braintrust services.
- `quarantine` VPC: This is a "quarantine" VPC where user defined functions run in an isolated environment. The Braintrust API server spawns lambda functions in this VPC.

### Tagging and Naming

If you have requirements to add custom tags to resources created by the module, you can do so by setting the `default_tags` variable on the AWS provider. The example directory [`examples/braintrust-data-plane`](examples/braintrust-data-plane) shows how to do this.

Example:
```hcl
provider "aws" {
  default_tags {
    tags = {
      YourCustomTag = "<your-custom-value>"
    }
  }
}
```

The `deployment_name` variable is also used to prefix the names of the resources created by the module wherever possible. It will also be applied as a tag named `BraintrustDeploymentName` to all resources created by the module.

### CloudFront Access Logging

If you need to enable CloudFront standard access logging, you can configure it independently by referencing the `cloudfront_distribution_arn` output from the module. This approach gives you full flexibility over the logging configuration without requiring changes to the module itself.

See the [`examples/cloudfront-logging`](examples/cloudfront-logging) directory for a complete example showing how to set up V2 logging to S3.

## Advanced: Customized Deployments

### Using an Existing VPC

The module supports using an existing VPC instead of creating a new dedicated one for the Braintrust services. This is useful when you want to integrate Braintrust into your existing network infrastructure.

The passed in VPC must have the following resources:
- At least 3 private subnets in different availability zones
- At least 1 public subnet
- Internet gateway and NAT gateway with proper route tables configured for private subnets

Important note: The module will still create and manage security groups for the services.

To use an existing VPC, set `create_vpc = false` and provide the required VPC details:

```hcl
module "braintrust-data-plane" {
  source = "github.com/braintrustdata/terraform-braintrust-data-plane"

  # ... your existing configuration ...

  # Use existing VPC
  create_vpc = false
  existing_vpc_id                        = "vpc-xxxxxxxxx"
  existing_private_subnet_1_id           = "subnet-xxxxxxxxx"
  existing_private_subnet_2_id           = "subnet-yyyyyyyyy"
  existing_private_subnet_3_id           = "subnet-zzzzzzzzz"
  existing_public_subnet_1_id            = "subnet-aaaaaaaaa"
}
```

## Development Setup

This section is only relevant if you are a contributor who wants to make changes to this module. All others can skip this section.

1. Clone the repository
2. Install [mise](https://mise.jdx.dev/about.html):
    ```
    curl https://mise.run | sh
    echo 'eval "$(mise activate zsh)"' >> "~/.zshrc"
    echo 'eval "$(mise activate zsh --shims)"' >> ~/.zprofile
    exec $SHELL
    ```
3. Run `mise install` to install required tools
4. Run `mise run setup` to install pre-commit hooks
