# Braintrust Terraform Module

This module is used to create the VPC, Databases, Lambdas, and associated resources for the self-hosted Braintrust data plane.

**NOTE: This module is not yet ready for use. It is still under development.**

## How to use this module

To use this module, create a new Terraform directory and copy:
* `providers.tf_example` to `providers.tf`
* `terraform.tf_example` to `terraform.tf`

Modifying their values as needed to match your environment.

Then create a `main.tf` and add the following:

```hcl
module "braintrust" {
  source = "github.com/braintrustdata/terraform-braintrust-data-plane"
  # Optional parameters.
  # These already have defaults, but feel free to override them:
  #
  # deployment_name = "braintrust"
  # vpc_cidr = "172.29.0.0/16"
  # enable_quarantine = true
  # quarantine_vpc_cidr = "172.29.0.0/16"
}
```

## Customized Deployments

It is highly recommended to use our root module to deploy Braintrust. It will make support and upgrades far easier. However, if you need to customize the deployment, you can pick and choose from our submodules since they are easily composable.

Look at our `main.tf` as a reference for how to configure the submodules. For example, if you wanted to re-use an existing VPC, you could remove the `module.main_vpc` block and pass in the existing VPC's ID, subnets, and security group IDs to the `services`, `database`, and `redis` modules.


## Development Setup

You only need to do these steps if you are making changes to this module.

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
