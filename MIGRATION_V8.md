# Migrating to v8

Upgrade this Terraform module **one major version at a time**. See the [README](README.md#major-versions) for the general upgrade policy, and the [routine upgrade guide](https://docs.braintrust.dev/admin/self-hosting/upgrade/routine) for the standard process of bumping the module version and applying Terraform.

v8 removes the Lambda API path. Every standard deployment runs the API on ECS and routes API services through the private AI gateway. There is no option to turn either off.

## Before you upgrade

Finish the v7 cutover first. On your current v7 version, the stack must already run:

```hcl
enable_ecs_api    = true
create_ai_gateway = true
enable_ai_gateway = true
```

These are the v7 defaults, so a v7 stack that omits all three is already in the right state. Confirm with a v7 `terraform plan` that shows no changes before you bump the module.

Do **not** upgrade a stack that still sets `enable_ecs_api = false`, `create_ai_gateway = false`, or `enable_ai_gateway = false`. Cut over on v7 using [MIGRATION_V7.md](MIGRATION_V7.md), confirm traffic is healthy, then upgrade.

## Remove these inputs

v8 no longer accepts these inputs. Delete them from your module block or the plan fails with `Unsupported argument`:

| Removed input | Why |
| --- | --- |
| `enable_ecs_api` | The API always runs on ECS. |
| `create_ai_gateway` | The private gateway is always created. |
| `enable_ai_gateway` | API services and Loop always use the private gateway. |
| `use_global_ai_proxy` | Only applied to the AIProxy Lambda origin. |
| `api_handler_provisioned_concurrency` | APIHandler Lambda is gone. |
| `api_handler_reserved_concurrent_executions` | APIHandler Lambda is gone. |
| `api_handler_memory_limit` | APIHandler Lambda is gone. |
| `ai_proxy_reserved_concurrent_executions` | AIProxy Lambda is gone. |
| `ai_proxy_memory_limit` | AIProxy Lambda is gone. |

`service_extra_env_vars` no longer has `APIHandler` or `AIProxy` keys. Move any values you set there to `braintrust_api_extra_env_vars` (API ECS) or `ai_gateway_extra_env_vars` (gateway) if you still need them.

## What changes on apply

On a stack that already cut over on v7, the upgrade plan should only show:

- The `api_gateway` entry in the `monitoring_contract` output reports `enabled = false` with null `name` and `stage`. Its shape is unchanged, so version-2 consumers keep planning.
- The `CloudflareProxy` origin is removed from the CloudFront distribution. Nothing routed to it in ECS mode.
- The `<deployment>-APIHandler-Lambdas` IAM policy and the `AWSLambdaVPCAccessExecutionRole` attachment are removed from the `APIHandlerRole`. The role itself stays: API ECS tasks use it.

No API ECS, gateway, Brainstore, database, or Redis resources are replaced.

`use_private_ai_gateway_origin` and `use_global_ai_gateway_origin` remain. They choose which origin CloudFront uses for `/v1/proxy`. With both `false`, CloudFront sends `/v1/proxy` to the API ECS load balancer.

## Quarantine proxy URL

The AI Proxy Function URL fallback is gone. API ECS sets `QUARANTINE_PROXY_URL` from, in order:

1. `quarantine_proxy_url`, if set.
2. The quarantine PrivateLink endpoint, when `use_private_gateway_quarantine_proxy` creates it.
3. `https://<cloudfront-domain>/v1/proxy`.

This is the same selection a v7 ECS-mode stack already uses.

## External EKS

External EKS deployments never used these inputs. Remove them from the module block if present. Helm still owns the API and gateway.

## Rollback

Rolling back to v7 is safe for a stack that applied v8 from the cut-over state. The v7 defaults keep ECS and the gateway enabled. Re-add any removed inputs you need with their v7 values. Do not set `enable_ecs_api = false` on rollback: that recreates APIHandler, AIProxy, a new Function URL hostname, and API Gateway.
