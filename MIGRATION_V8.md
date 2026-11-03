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
| `create_ai_gateway` | Derived: the private gateway exists unless `use_global_ai_gateway_origin = true`. |
| `enable_ai_gateway` | Derived: API services and Loop always use the selected gateway. |
| `use_private_ai_gateway_origin` | Derived: CloudFront `/v1/proxy` uses the private gateway unless `use_global_ai_gateway_origin = true`. |
| `use_global_ai_proxy` | Only applied to the AIProxy Lambda origin. |
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
- The `CloudflareProxy` origin is removed from the CloudFront distribution. Nothing routed to it in ECS mode.
- The `<deployment>-APIHandler-Lambdas` IAM policy and the `AWSLambdaVPCAccessExecutionRole` attachment are removed from the `APIHandlerRole`. The role itself stays: API ECS tasks use it.

No API ECS, gateway, Brainstore, database, or Redis resources are replaced.

CloudFront `/v1/proxy` always routes to the selected gateway, never to the API ECS load balancer.

If a hosted-gateway stack also set `create_ai_gateway = true`, v8 **destroys** that private gateway ALB and ECS service, because the hosted gateway replaces it. Set `use_global_ai_gateway_origin = false` instead to keep the private gateway.

## Quarantine proxy URL

The AI Proxy Function URL fallback is gone. API ECS sets `QUARANTINE_PROXY_URL` from, in order:

1. `quarantine_proxy_url`, if set.
2. The quarantine PrivateLink endpoint, when `use_private_gateway_quarantine_proxy` creates it (private gateway only).
3. `https://<cloudfront-domain>/v1/proxy`, which CloudFront serves from the selected gateway.

This is the same selection a v7 ECS-mode stack already uses.

## External EKS

External EKS deployments never used these inputs. Remove them from the module block if present. Helm still owns the API and gateway.

## Rollback

v7 defaults keep ECS and the private gateway enabled, so a v8 private-gateway stack rolls back without extra settings. A hosted-gateway stack must add `create_ai_gateway = false`, `enable_ai_gateway = false`, and `use_private_ai_gateway_origin = false` on rollback, or v7 builds a private gateway. Do not set `enable_ecs_api = false` on rollback: that recreates APIHandler, AIProxy, a new Function URL hostname, and API Gateway.
