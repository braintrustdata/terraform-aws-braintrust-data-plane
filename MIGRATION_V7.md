# Migrating to v7

Upgrade this Terraform module **one major version at a time**. See the [README](README.md#major-versions) for the general upgrade policy, and the [routine upgrade guide](https://www.braintrust.dev/docs/admin/self-hosting/upgrade/routine) for the standard process of bumping the module version and applying Terraform.

A new stack that sets nothing gets ECS ingress and the private gateway.

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
