# Braintrust Terraform Module

This module is used to create the VPC, Databases, Lambdas, and associated resources for the self-hosted Braintrust data plane.

## How to use this module

To use this module, **copy the [`examples/braintrust-data-plane`](examples/braintrust-data-plane) directory to a new Terraform directory in your own repository**. Follow the instructions in the [`README.md`](examples/braintrust-data-plane/README.md) file in that directory to configure the module for your environment.

If you're using a brand new AWS account for your Braintrust data plane you will need to run ./scripts/create-service-linked-roles.sh once to ensure IAM service-linked roles are created.

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

## Customized Deployments

It is highly recommended to use our root module to deploy Braintrust. It will make support and upgrades far easier. However, if you need to customize the deployment, you can pick and choose from our submodules since they are easily composable.

Look at our `main.tf` as a reference for how to configure the submodules. For example, if you wanted to re-use an existing VPC, you could remove the `module.main_vpc` block and pass in the existing VPC's ID, subnets, and security group IDs to the `services`, `database`, and `redis` modules.


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
