# Migrating to v7

Upgrade this Terraform module **one major version at a time**. See the [README](README.md#major-versions) for the general upgrade policy, and the [routine upgrade guide](https://docs.braintrust.dev/admin/self-hosting/upgrade/routine) for the standard process of bumping the module version and applying Terraform.

Starting with version v7, the module will default to running the API and a braintrust ai gateway instance in ECS.

On v6 an omitted `enable_ecs_api` means Lambda. On v7 an omitted `enable_ecs_api` means ECS. Finish the v6 applies before this upgrade so the v7 apply does not move a stack that was still on Lambda. Stacks that follow Stay on Lambda, Gateway off, or Hosted gateway instead skip those applies.

Before a rollback to v6, set `enable_ecs_api = true` in the config. On v6 the default is false, so an omitted flag recreates the Lambda path (APIHandler, AIProxy, the Function URL, and API Gateway).

## v6 applies

For people who have not done it yet, do not start this upgrade until the v6 applies have succeeded, except stacks that follow Stay on Lambda, Gateway off, or Hosted gateway instead.

1. The first v6 apply builds API ECS. On v6 there is no create flag. `enable_ecs_api` stays `false`, which was the v6 default, and customer traffic stays on Lambda.

2. Build the gateway and leave traffic where it is. `enable_ecs_api` stays `false`.

   ```hcl
   create_ai_gateway             = true
   enable_ai_gateway             = false
   use_private_ai_gateway_origin = false
   enable_ecs_api                = false
   ```

3. Cut over together:

   ```hcl
   enable_ecs_api                = true
   enable_ai_gateway             = true
   use_private_ai_gateway_origin = true
   ```

## Private gateway

The v6 applies are finished. `enable_ecs_api = true` matches the v7 default. People who already cut over can leave the line or drop it.

```hcl
enable_ecs_api                = true
create_ai_gateway             = true
enable_ai_gateway             = true
use_private_ai_gateway_origin = true
```

## Stay on Lambda

### Gateway built, not enabled

A v6 step 2 stack already built the gateway and has not enabled it. Keep `create_ai_gateway = true` so this apply does not destroy the gateway ALB and ECS service. Turn `enable_ai_gateway` and `use_private_ai_gateway_origin` on in a later apply.

```hcl
enable_ecs_api                = false
create_ai_gateway             = true
enable_ai_gateway             = false
use_private_ai_gateway_origin = false
```

### Never built a gateway

The gateway must stay absent. Set all four flags false:

```hcl
enable_ecs_api                = false
create_ai_gateway             = false
enable_ai_gateway             = false
use_private_ai_gateway_origin = false
```

### Lambda plus an enabled private gateway

```hcl
enable_ecs_api = false
```

The three gateway flags default to `true`. Omitting the gateway flags means this apply builds the gateway if needed, enables it, and moves CloudFront `/v1/proxy`.

When the gateway exists, the gateway's default API address is still the private API ECS load balancer while customer traffic stays on Lambda.

## Gateway off

The default sends customer traffic to ECS. Omitting `enable_ecs_api` moves traffic to ECS. A stack still on Lambda that only sets the flags in this section is cut over to ECS on this apply, which removes APIHandler, AIProxy, the Function URL, and API Gateway.

```hcl
create_ai_gateway             = false
enable_ai_gateway             = false
use_private_ai_gateway_origin = false
```

Setting only `create_ai_gateway = false` is not enough. The other two default to `true` and the plan fails.

Staying on Lambda means also setting:

```hcl
enable_ecs_api = false
```

## Hosted gateway

The default sends customer traffic to ECS. Omitting `enable_ecs_api` moves traffic to ECS. A stack still on Lambda that only sets the flags in this section is cut over to ECS on this apply, which removes APIHandler, AIProxy, the Function URL, and API Gateway.

```hcl
use_global_ai_gateway_origin         = true
use_private_ai_gateway_origin        = false
create_ai_gateway                    = false
enable_ai_gateway                    = false
use_private_gateway_quarantine_proxy = false
```

Setting only the two origin flags still builds the private gateway and points API services and Loop at it, because `create_ai_gateway` and `enable_ai_gateway` default to `true`. `use_private_gateway_quarantine_proxy` must be `false` because `create_ai_gateway = false` fails that check.

Staying on Lambda means also setting:

```hcl
enable_ecs_api = false
```

## External EKS

Terraform ignores `enable_ecs_api`, `create_ai_gateway`, `enable_ai_gateway`, and `use_private_ai_gateway_origin`. Helm owns the gateway. External EKS mode does not create the gateway. `use_private_gateway_quarantine_proxy = true` fails the plan. Terraform does not ignore that flag, so `use_private_gateway_quarantine_proxy` must be `false`. `braintrust_api_url` is a legacy input and is not required.

Stacks that already built a gateway with Terraform must move to the Helm gateway and repoint before upgrading. The upgrade destroys that ALB, ECS service, and ECS cluster.

## v7.3.0 IAM ownership tag

Release `v7.3.0` tags every IAM role, managed policy and instance profile that the module creates with `BraintrustIAMOwner = "braintrust"`. On an existing stack this is an in-place tag update. Nothing is replaced. The module reserves the key, so setting `BraintrustIAMOwner` in `custom_tags` fails at plan time, in any letter case.

Check these before you apply it.

1. The principal that runs `terraform apply` needs `iam:TagRole`, `iam:TagPolicy` and `iam:TagInstanceProfile`, plus `iam:ListRoleTags`, `iam:ListPolicyTags` and `iam:ListInstanceProfileTags` so Terraform can read the tags back.
1. Look at any SCP or permissions boundary that has a condition on tag keys, such as `aws:RequestTag` or `aws:TagKeys`. This is the most likely thing to block the new tag.
1. An organization tag policy only matters if it defines `BraintrustIAMOwner` or a differently cased variant of it. Tag policies don't block keys they don't mention.
1. IAM allows 50 tags per resource. A role that is already close to that limit can't take another tag.
1. Don't set the key in the AWS provider's `default_tags`. The module can't validate those, and the module's own value has to be the one that applies.

The module pins Braintrust service versions, so changing the module version also moves your services. Coming from v7.2.1, the upgrade plan includes more than the tags:

- Services move to the version this release pins, and the database migrations for that version run.
- A new Secrets Manager secret holds the Brainstore license key, unless you supply one with `existing_brainstore_license_key_secret`.
- API and gateway ECS task definitions are replaced, so those services roll.
- Brainstore launch templates change, so Brainstore instances refresh. This includes an IMDS hop limit of 1, so containers on a Docker bridge network on those instances can no longer get credentials from IMDS.

To keep the service upgrade out of this apply, pin each service to the version you run now, for example `v2.22.0` on v7.2.1:

```hcl
  lambda_version_tag_override     = "v2.22.0"
  braintrust_api_version_override = "v2.22.0"
  ai_gateway_version_override     = "v2.22.0"
  loop_runtime_version_override   = "v2.22.0"
  brainstore_version_override     = "v2.22.0"
```

Apply, confirm the stack is healthy, then remove the overrides in a later apply. That one moves services to the pinned version and runs its migrations. We tested this path from v7.2.1 to v7.3.0, except for `loop_runtime_version_override`. If you run Loop, check its version after the first apply.

For IAM, going back to an earlier version only removes the tag, since the older module doesn't set it. It doesn't replace any IAM. Going back to v7.2.1 also returns the license key to plaintext task definitions and user data, deletes the module-created license secret, and moves services back to v7.2.1's pinned version after the newer migrations have run.
