# Braintrust Terraform Module

This module is used to create the VPC, Databases, Lambdas, and associated resources for the self-hosted Braintrust data plane.

## How to use this module

To use this module, **copy the [`examples/braintrust-data-plane`](examples/braintrust-data-plane) directory to a new Terraform directory in your own repository**. Follow the instructions in the [`README.md`](examples/braintrust-data-plane/README.md) file in that directory to configure the module for your environment.

The default configuration is a large production-sized deployment. Please consider that when testing and adjust the configuration to use smaller sized resources.

If you're using a brand new AWS account for your Braintrust data plane you will need to run ./scripts/create-service-linked-roles.sh once to ensure IAM service-linked roles are created.

## Module Configuration
All module input variables and outputs are documented inline in the module's Terraform files (see `variables.tf`, `outputs.tf`, and the submodules for details).

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
