# External IAM example

Deploys a data plane when your security team creates the IAM and you deploy everything else.

## What is this?

With `create_iam = false` the module creates no IAM role, policy or instance profile, no S3 bucket policy and no Lambda permission. It looks up each role and the Brainstore instance profile that your security team created, and it fails the plan unless every one carries `BraintrustIAMOwner = customer`. You still own the buckets, log groups, functions, compute and the KMS key.

This is for new stacks only. The first apply creates `terraform_data.iam_ownership_mode`, which records the `create_iam` value and fails any later plan that changes it. A flip to external mode would plan to destroy every role the stack created, and that stops every workload.

## Before you start

- Your security team runs `modules/iam` on its own with `iam_owner = "customer"`, in the same account and region, with the same `deployment_name`, `override_iam_names` and feature flags that you set here. It creates every role this stack looks up. It creates no default role and no AIProxy invoke role.
- The roles carry `BraintrustIAMOwner = customer`. `modules/iam` sets it for you.
- A supplied main VPC and, with quarantine, a supplied quarantine VPC and its three private subnets. External mode rejects a module-managed VPC.
- Your security team applies the TLS-only bucket policies on the three module-created buckets. The module writes none of them, and it doesn't check that they exist.
- The service-linked roles that your deployment needs. Run `scripts/create-service-linked-roles.sh` for the Auto Scaling role.

External mode needs ECS ingress (`enable_ecs_api = true`) and supplied networks, and it rejects several features and inputs. [MIGRATION_V8.md](../../MIGRATION_V8.md#what-external-mode-rejects) lists them. It also shows the standalone `modules/iam` call, the inputs both calls must match and what to provide before the first apply.

## How do I configure this thing?

1. Copy this directory into your own repository.
2. Edit `provider.tf` for your AWS account, region and credential profile.
3. Edit `terraform.tf` for your remote backend.
4. Edit `main.tf` for your organization, networks and capacity.
5. Supply `brainstore_license_key` through your deployment environment or secret manager.

Roles and the instance profile resolve in this order:

| Input | Behavior |
| --- | --- |
| Nothing | The module looks up the default names, such as `braintrust-APIHandlerRole`, which come from `deployment_name`. |
| `override_iam_names` | A sparse map keyed `role.<key>` or `instance_profile.brainstore`, with `name` and `path`. A field you leave out keeps its default. |
| `existing_iam` | A role entry takes an `arn`, and the instance profile entry takes an `arn` or a `name`. The module reads each one back and applies the same checks. |

## What does the module check?

Each lookup is a postcondition, so a failure stops the plan.

1. A role tagged `BraintrustIAMOwner = braintrust` fails with a message that a module-managed stack owns it. Setting `create_iam = false` would destroy it.
2. A role with no tag fails too. A stack that skipped v7.3.0 never received the `braintrust` tag.
3. The role's ARN must be in this partition and account, and its path must match the override or `/`.
4. No two roles may resolve to the same name.
5. The instance profile must hold the Brainstore role.

## What happens in the first few minutes of a new stack?

Alias-based KMS authorization can take a few minutes after the alias exists. If you see `AccessDenied` on KMS or Secrets Manager from the first API deployment, the migration, quarantine warmup or Brainstore, apply again. If that plan shows no changes, force a new API ECS deployment or start a Brainstore instance refresh. See "The first minutes of a new stack" in [MIGRATION_V8.md](../../MIGRATION_V8.md).

## Teardown

A plain `terraform destroy` works. Destroy this stack before your security team deletes the roles, because the lookups run on destroy plans too.

## Resources

- [MIGRATION_V8.md](../../MIGRATION_V8.md#external-iam-mode-create_iam--false) - The ownership checks, the rejections, security's standalone call and teardown in full.
