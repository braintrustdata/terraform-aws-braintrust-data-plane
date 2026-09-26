# Migrating to v7

Upgrade this Terraform module **one major version at a time**. See the [README](README.md#major-versions) for the general upgrade policy, and the [routine upgrade guide](https://www.braintrust.dev/docs/admin/self-hosting/upgrade/routine) for the standard process of bumping the module version and applying Terraform.

v7 removes the API and ingest Lambda path on deployments that are already serving traffic from ECS. Quarantine, database migration, CatchupETL, billing cron, and automation cron stay.

## What changed

When `enable_ecs_api` is **true**, Terraform destroys:

- `APIHandler` and `AIProxy`, including the public AI Proxy Function URL, its public invoke permissions, and the `/braintrust/<deployment>/ai-proxy-url` SSM parameter
- API Gateway, which existed only to invoke `APIHandler`
- the CloudFront origins for API Gateway and the AI Proxy Function URL (traffic is already on the ECS origin)

When `enable_ecs_api` is **false**, those resources stay. State addresses move from uncounted resources to `[0]` so the apply does not recreate them.

A stack that already set `enable_ecs_api = true` on v6 deletes those resources in the v7 version-bump apply itself. There is no extra apply that keeps the Lambdas up after the bump.

Loop Runtime already uses the private gateway or the CloudFront API URL, not the Function URL.

Quarantine UDFs do not keep using that Function URL. On v6 they reached it through the quarantine VPC's NAT gateway. v7 points them at the CloudFront API URL `/v1/proxy` through that same NAT, unless `quarantine_proxy_url` or PrivateLink already set a URL. Leaving every source empty is rejected, because api-ts would then hand the quarantine Lambda `http://localhost:8000/v1/proxy`.

## Upgrade steps

1. Finish the [v6 ECS cutover](MIGRATION_V6.md) if this deployment should run on ECS. That cutover is `enable_ecs_api = true` on v6, while APIHandler and AIProxy still exist.
2. Quarantine on a module-managed VPC needs no new setting. v7 sends those UDFs to `https://<cloudfront-domain>/v1/proxy` over the existing NAT gateway. Set `quarantine_proxy_url` or `use_private_gateway_quarantine_proxy` only to override that. Both inputs exist on v6.7.0 and later; apply an override on that version before the bump if you want it in place first.
3. Bump to v7.
   - Already on ECS (`enable_ecs_api = true`): apply deletes APIHandler, AIProxy, and API Gateway.
   - Still on Lambda: keep `enable_ecs_api = false` for this apply. It only moves Lambda and API Gateway state to count indexes. A later apply that sets `enable_ecs_api = true` deletes them, and must include the quarantine proxy from step 2.

## Quarantine proxy after the Function URL

The default is the CloudFront distribution URL plus `/v1/proxy`. A module-managed quarantine VPC already has a NAT gateway, which is how it reached the Function URL. In plain ECS mode CloudFront sends that path to the API service. That is the default on purpose.

These override it, in order:

- `quarantine_proxy_url`, including a hosted gateway URL. Prompt traffic then leaves the account. `use_global_ai_gateway_origin` does not set this; it only changes where CloudFront sends `/v1/proxy`.
- PrivateLink, when `use_private_gateway_quarantine_proxy` and `create_ai_gateway` are set and this module creates both VPCs. Traffic stays off the public internet. This adds an internal network load balancer.

A customer-supplied quarantine VPC (`existing_quarantine_vpc_id`) may have no internet egress. The module cannot tell, and it will still default to CloudFront. A public URL will not work then. Set `quarantine_proxy_url` to a private endpoint such as `http://<vpce-dns>/v1/proxy`. Do not point that URL at the API load balancer or the gateway load balancer. Those are private to the main VPC.

## Rollback

Setting `enable_ecs_api` back to `false` recreates APIHandler, AIProxy (including a new public Function URL hostname), provisioned concurrency, and API Gateway. It is not a CloudFront-only flip. Brainstore's AI proxy SSM selector also changes back to the bare `/braintrust/<deployment>/ai-proxy-url` name in that same apply, while the parameter is being recreated. Replacement Brainstore instances can boot before the parameter exists.

Downgrading the module after an apply is not safe. The previous version addresses these resources without `[0]`, so a downgrade plan recreates the Lambdas and API Gateway.

## What stays

- QuarantineWarmupFunction and the quarantine functions it creates outside Terraform
- MigrateDatabaseFunction
- CatchupETL
- BillingCron
- AutomationCron
