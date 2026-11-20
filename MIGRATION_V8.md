# Migrating to v8

Upgrade this Terraform module **one major version at a time**. See the [README](README.md#major-versions) for the general upgrade policy, and the [routine upgrade guide](https://docs.braintrust.dev/admin/self-hosting/upgrade/routine) for the standard process of bumping the module version and applying Terraform.

v8 removes the Lambda API path and the hosted-gateway option. Every standard deployment runs the API on ECS and the private AI gateway in your VPC. There is no option to run on Lambda, without a gateway, or on the hosted Braintrust gateway.

Braintrust native inference models still work: the private gateway forwards those requests to the Braintrust gateway, which serves them. Other model calls go from your VPC to the provider.

## Before you upgrade

Finish the v7 ECS cutover first. Your current v7 stack must run `enable_ecs_api = true` (the v7 default) and the private gateway, which is also the v7 default, so omitting all four of these is fine:

```hcl
create_ai_gateway             = true
enable_ai_gateway             = true
use_private_ai_gateway_origin = true
use_global_ai_gateway_origin  = false
```

Confirm with a v7 `terraform plan` that shows no changes before you bump the module.

Do **not** upgrade a stack that still sets `enable_ecs_api = false`. Cut over on v7 using [MIGRATION_V7.md](MIGRATION_V7.md), confirm traffic is healthy, then upgrade.

Before that cutover, move any `APIHandler` and `AIProxy` entries in `service_extra_env_vars` to `braintrust_api_extra_env_vars` (API ECS) or `ai_gateway_extra_env_vars` (gateway). API ECS and the gateway don't read the Lambda keys, so settings left there stop applying when traffic moves to ECS.

A stack on the hosted gateway (`use_global_ai_gateway_origin = true`), with no gateway, or with a private gateway that is built but not enabled must switch to the private gateway on v7 first. Set the values above (or remove them to take the defaults), apply, and confirm model traffic is healthy. The switch creates the gateway ECS service and its internal ALB, which add AWS charges, and moves CloudFront `/v1/proxy`, `GATEWAY_URL` and Loop onto it. Terraform waits for the gateway ECS service to reach steady state before callers move.

If you skip that step, a stack that still sets `use_global_ai_gateway_origin` fails the v8 plan with `Unsupported argument`. Removing the input instead makes the v8 upgrade apply do the switch too, which we don't support.

## Remove these inputs

v8 no longer accepts these inputs. Delete them from your module block or the plan fails with `Unsupported argument`:

| Removed input | Why |
| --- | --- |
| `enable_ecs_api` | The API always runs on ECS. |
| `create_ai_gateway` | The private gateway (ECS service, internal ALB, and CloudFront VPC origin) always exists. |
| `enable_ai_gateway` | API ECS (`GATEWAY_URL`), Loop, and CloudFront `/v1/proxy` always use the private gateway. |
| `use_private_ai_gateway_origin` | CloudFront `/v1/proxy` always uses the private gateway. |
| `use_global_ai_gateway_origin` | The hosted-gateway option is gone. |
| `global_ai_gateway_origin_domain` | Only applied to the hosted gateway. |
| `use_global_ai_proxy` | Only applied to the AIProxy Lambda origin. |
| `api_handler_provisioned_concurrency` | APIHandler Lambda is gone. |
| `api_handler_reserved_concurrent_executions` | APIHandler Lambda is gone. |
| `api_handler_memory_limit` | APIHandler Lambda is gone. |
| `ai_proxy_reserved_concurrent_executions` | AIProxy Lambda is gone. |
| `ai_proxy_memory_limit` | AIProxy Lambda is gone. |

`service_extra_env_vars` no longer has `APIHandler` or `AIProxy` keys. Remove them. On an ECS-mode v7 stack they already had no effect on API ECS or the gateway; any value you still need belongs in `braintrust_api_extra_env_vars` or `ai_gateway_extra_env_vars` (see [Before you upgrade](#before-you-upgrade)).

## What changes on apply

On a stack set up as above, the upgrade plan should only show:

- The `api_gateway` entry in the `monitoring_contract` output keeps its shape and `enabled = false`; `name` and `stage` become null.
- The `CloudflareProxy` and `GatewayOrigin` origins are removed from the CloudFront distribution. Nothing routed to either on an ECS-mode stack with the private gateway.
- The `<deployment>-APIHandler-Lambdas` IAM policy and the `AWSLambdaVPCAccessExecutionRole` attachment are removed from the `APIHandlerRole`. The role itself stays: API ECS tasks use it.

No API ECS, gateway, Brainstore, database, or Redis resources are replaced.

CloudFront `/v1/proxy` always routes to the private gateway, never to the API ECS load balancer.

## Quarantine proxy URL

The AI Proxy Function URL fallback is gone. API ECS sets `QUARANTINE_PROXY_URL` from, in order:

1. `quarantine_proxy_url`, if set.
2. The quarantine PrivateLink endpoint, when `use_private_gateway_quarantine_proxy` creates it.
3. `https://<cloudfront-domain>/v1/proxy`, which CloudFront serves from the private gateway.

This is the same selection a v7 ECS-mode stack already uses.

## External EKS

External EKS deployments never used these inputs. Remove them from the module block if present. Helm still owns the API and gateway.

## Rollback

Roll back to v7 with the v7 gateway defaults (the private gateway). v7 creates the same gateway resources, so nothing gateway-related is replaced. Keep the private gateway through the rollback; switching to the hosted gateway is a separate v7 change.

Do not set `enable_ecs_api = false` on rollback: that recreates APIHandler, AIProxy, a new Function URL hostname, and API Gateway.
