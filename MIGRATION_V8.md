# Migrating to v8

Upgrade this Terraform module **one major version at a time**. See the [README](README.md#major-versions) for the general upgrade policy, and the [routine upgrade guide](https://docs.braintrust.dev/admin/self-hosting/upgrade/routine) for the standard process of bumping the module version and applying Terraform.

v8 requires an AI gateway. Every standard deployment uses either the private gateway (the default) or the hosted Braintrust gateway. There is no option to run without one. CloudFront `/v1/proxy` always routes to the selected gateway, never to the AI Proxy Lambda, the Cloudflare proxy, or the API load balancer.

`enable_ecs_api` is unchanged. Lambda-mode stacks can upgrade.

## Remove these inputs

v8 no longer accepts these inputs. Delete them from your module block or the plan fails with `Unsupported argument`:

| Removed input | Replacement |
| --- | --- |
| `create_ai_gateway` | Derived: the private gateway exists unless `use_global_ai_gateway_origin = true`. |
| `enable_ai_gateway` | Derived: API services and Loop always use the selected gateway. |
| `use_private_ai_gateway_origin` | Derived: CloudFront `/v1/proxy` uses the private gateway unless `use_global_ai_gateway_origin = true`. |
| `use_global_ai_proxy` | None. The Cloudflare proxy origin is removed. |

`use_global_ai_gateway_origin` is now the only gateway choice.

## What changes on apply

Find your v7 configuration below.

### Private gateway enabled (v7 default)

`create_ai_gateway`, `enable_ai_gateway`, and `use_private_ai_gateway_origin` were all `true` or omitted. Remove the lines. The plan removes the unused `CloudflareProxy` CloudFront origin. If `enable_ecs_api = false`, the API ECS task definition also gets a new `QUARANTINE_PROXY_URL` (CloudFront `/v1/proxy` instead of the AI Proxy Function URL). It does not serve customer traffic in Lambda mode.

### Private gateway built, not enabled

`create_ai_gateway = true` with `enable_ai_gateway` or `use_private_ai_gateway_origin` set to `false`. v8 enables it on this apply: API services get `GATEWAY_URL`, Loop uses the private gateway, and CloudFront `/v1/proxy` moves to the private gateway. Check that the gateway ECS service is healthy before upgrading.

### No gateway

All three flags were `false`. Either:

- remove them and let v8 build and enable the private gateway in one apply (Terraform waits for gateway ECS steady state before callers switch), or
- set `use_global_ai_gateway_origin = true` to use the hosted gateway, only if Braintrust has told you to.

Model calls on `/v1/proxy` that went to the API load balancer or the AI Proxy Lambda move to the gateway.

### Hosted gateway

`use_global_ai_gateway_origin = true`. Keep it and remove the other gateway flags. If you also set `create_ai_gateway = true`, v8 **destroys** that private gateway ALB and ECS service, because the hosted gateway replaces it. Set `use_global_ai_gateway_origin = false` instead if you want to keep the private gateway.

### `use_global_ai_proxy = true`

Remove it. CloudFront `/v1/proxy` moves from the Cloudflare proxy to your selected gateway.

## Quarantine proxy URL

API ECS sets `QUARANTINE_PROXY_URL` from, in order:

1. `quarantine_proxy_url`, if set.
2. The quarantine PrivateLink endpoint, when `use_private_gateway_quarantine_proxy` creates it (private gateway only).
3. `https://<cloudfront-domain>/v1/proxy`, which CloudFront serves from the selected gateway.

The AI Proxy Function URL fallback is removed.

## External EKS

External EKS deployments ignore the gateway inputs. Remove any removed inputs from the module block. Helm still owns the gateway.

## Rollback

v7 defaults create and enable the private gateway, so a v8 private-gateway stack rolls back without extra settings. A hosted-gateway stack must add `create_ai_gateway = false`, `enable_ai_gateway = false`, and `use_private_ai_gateway_origin = false` on rollback, or v7 builds a private gateway.
