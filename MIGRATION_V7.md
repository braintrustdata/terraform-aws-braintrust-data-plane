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

Quarantine UDFs do not. On v6 they used the AI Proxy Function URL. v7 removes that URL. If `enable_quarantine_vpc` is true, the apply fails unless `quarantine_proxy_url` is set or `use_private_gateway_quarantine_proxy` has created a PrivateLink URL. `use_global_ai_gateway_origin` is not a substitute: quarantine cannot call CloudFront or the hosted gateway from the fallback. Leaving `QUARANTINE_PROXY_URL` unset makes api-ts hand the quarantine Lambda `http://localhost:8000/v1/proxy`.

## Upgrade steps

1. Finish the [v6 ECS cutover](MIGRATION_V6.md) if this deployment should run on ECS. That cutover is `enable_ecs_api = true` on v6, while APIHandler and AIProxy still exist.
2. If quarantine is enabled, set a reachable proxy and apply **on v6**, before the bump:
   - `quarantine_proxy_url`, or
   - `use_private_gateway_quarantine_proxy` with `create_ai_gateway` and module-managed VPCs.
3. Bump to v7.
   - Already on ECS (`enable_ecs_api = true`): apply deletes APIHandler, AIProxy, and API Gateway.
   - Still on Lambda: keep `enable_ecs_api = false` for this apply. It only moves Lambda and API Gateway state to count indexes. A later apply that sets `enable_ecs_api = true` deletes them, and must include the quarantine proxy from step 2.

## Rollback

Setting `enable_ecs_api` back to `false` recreates APIHandler, AIProxy (including a new public Function URL hostname), provisioned concurrency, and API Gateway. It is not a CloudFront-only flip. Brainstore's AI proxy SSM selector also changes back to the bare `/braintrust/<deployment>/ai-proxy-url` name in that same apply, while the parameter is being recreated. Replacement Brainstore instances can boot before the parameter exists.

Downgrading the module after an apply is not safe. The previous version addresses these resources without `[0]`, so a downgrade plan recreates the Lambdas and API Gateway.

## What stays

- QuarantineWarmupFunction and the quarantine functions it creates outside Terraform
- MigrateDatabaseFunction
- CatchupETL
- BillingCron
- AutomationCron
