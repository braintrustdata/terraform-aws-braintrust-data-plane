# Migrating to v8

Upgrade this Terraform module **one major version at a time**. See the [README](README.md#major-versions) for the general upgrade policy, and the [routine upgrade guide](https://docs.braintrust.dev/admin/self-hosting/upgrade/routine) for the standard process of bumping the module version and applying Terraform.

v8 removes the Lambda API path and requires an AI gateway. Every standard deployment runs the API on ECS and uses either the private gateway (the default) or the hosted Braintrust gateway. There is no option to run on Lambda or without a gateway.

## Before you upgrade

Finish the v7 ECS cutover first. Your current v7 stack must run `enable_ecs_api = true` (the v7 default) and one of these gateway setups.

**Private gateway** (the v7 default, so omitting all three is fine):

```hcl
create_ai_gateway             = true
enable_ai_gateway             = true
use_private_ai_gateway_origin = true
```

**Hosted gateway:**

```hcl
use_global_ai_gateway_origin  = true
create_ai_gateway             = false
enable_ai_gateway             = false
use_private_ai_gateway_origin = false
```

Confirm with a v7 `terraform plan` that shows no changes before you bump the module.

Do **not** upgrade a stack that still sets `enable_ecs_api = false`. Cut over on v7 using [MIGRATION_V7.md](MIGRATION_V7.md), confirm traffic is healthy, then upgrade.

A stack with no gateway, or a private gateway that is built but not enabled, should first move to one of the two setups above on v7. Otherwise v8 builds and enables the private gateway in the upgrade apply, which also moves CloudFront `/v1/proxy` onto it.

## Remove these inputs

v8 no longer accepts these inputs. Delete them from your module block or the plan fails with `Unsupported argument`:

| Removed input | Why |
| --- | --- |
| `enable_ecs_api` | The API always runs on ECS. |
| `create_ai_gateway` | Derived: the gateway ECS service runs unless `use_global_ai_gateway_origin = true`. The gateway ALB and CloudFront VPC origin always exist. |
| `enable_ai_gateway` | Derived: API ECS (`GATEWAY_URL`), Loop, and CloudFront `/v1/proxy` always use the selected gateway. |
| `use_private_ai_gateway_origin` | Derived: CloudFront `/v1/proxy` uses the private gateway unless `use_global_ai_gateway_origin = true`. |
| `use_global_ai_proxy` | Only applied to the AIProxy Lambda origin. The unused `CloudflareProxy` origin stays in the distribution so the upgrade does not modify it. |
| `api_handler_provisioned_concurrency` | APIHandler Lambda is gone. |
| `api_handler_reserved_concurrent_executions` | APIHandler Lambda is gone. |
| `api_handler_memory_limit` | APIHandler Lambda is gone. |
| `ai_proxy_reserved_concurrent_executions` | AIProxy Lambda is gone. |
| `ai_proxy_memory_limit` | AIProxy Lambda is gone. |

`use_global_ai_gateway_origin` is now the only gateway choice.

`service_extra_env_vars` no longer has `APIHandler` or `AIProxy` keys. Move any values you set there to `braintrust_api_extra_env_vars` (API ECS) or `ai_gateway_extra_env_vars` (gateway) if you still need them.

## What changes on apply

On a stack in one of the two setups above, the upgrade plan should only show:

- The `api_gateway` entry in the `monitoring_contract` output keeps its shape and `enabled = false`; `name` and `stage` become null.
- The `<deployment>-APIHandler-Lambdas` IAM policy and the `AWSLambdaVPCAccessExecutionRole` attachment are removed from the `APIHandlerRole`. The role itself stays: API ECS tasks use it.

No API ECS, gateway, Brainstore, database, or Redis resources are replaced.

CloudFront `/v1/proxy` always routes to the selected gateway, never to the API ECS load balancer.

Hosted-gateway stacks also see:

- `GATEWAY_URL = https://<global_ai_gateway_origin_domain>` on API ECS, so in-process API model calls use the hosted gateway. On v7 these had no `GATEWAY_URL`.
- The internal gateway ALB and its CloudFront VPC origin are created and left idle, so a later switch to the private gateway does not create or delete them. The ALB has a small hourly charge.

## Quarantine proxy URL

The AI Proxy Function URL fallback is gone. API ECS sets `QUARANTINE_PROXY_URL` from, in order:

1. `quarantine_proxy_url`, if set.
2. The quarantine PrivateLink endpoint, when `use_private_gateway_quarantine_proxy` creates it (private gateway only).
3. `https://<cloudfront-domain>/v1/proxy`, which CloudFront serves from the selected gateway.

This is the same selection a v7 ECS-mode stack already uses.

## Switching gateways later

Changing `use_global_ai_gateway_origin` in either direction never deletes the gateway ALB or CloudFront VPC origin; only the `/v1/proxy` behavior, `GATEWAY_URL`, Loop's URL, and the gateway ECS service change. Switching to the private gateway waits for the gateway ECS service to reach steady state before callers move. This removes the known VPC-origin deletion failure, but a live switch has not been verified against AWS yet. The hosted gateway accepts the same control-plane credential the private gateway does, so `GATEWAY_URL` needs no extra auth setup in hosted mode.

## External EKS

External EKS deployments never used these inputs. Remove them from the module block if present. Helm still owns the API and gateway.

## Rollback

v7 defaults keep the private gateway enabled, so a v8 private-gateway stack rolls back without extra settings.

Rolling a **hosted-gateway** stack straight back to v7 is not supported. v7 ties the CloudFront VPC origin's lifetime to `use_private_ai_gateway_origin`, so that rollback deletes the origin that v8 keeps attached, and a failed delete can repeat on every apply. Instead:

1. On v8, set `use_global_ai_gateway_origin = false` and apply. This switches to the private gateway without deleting the VPC origin.
2. Roll back to v7 with its defaults (private gateway enabled). Nothing gateway-related is deleted.

Moving that v7 stack back to the hosted gateway hits the same VPC-origin limitation v7 already has, so stay on the private gateway until you can upgrade again.

Do not set `enable_ecs_api = false` on rollback: that recreates APIHandler, AIProxy, a new Function URL hostname, and API Gateway.
