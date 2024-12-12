# Braintrust Terraform Module

This module is used to create the VPC, Databases, Lambdas, and associated resources for the self-hosted Braintrust data plane.

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
