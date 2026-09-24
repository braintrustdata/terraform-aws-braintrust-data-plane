# Migrating to v7

Upgrade this Terraform module **one major version at a time**. See the [README](README.md#major-versions) for the general upgrade policy, and the [routine upgrade guide](https://www.braintrust.dev/docs/admin/self-hosting/upgrade/routine) for the standard process of bumping the module version and applying Terraform.

v7 removes the API and ingest Lambda path once a deployment is fully on ECS. Quarantine, database migration, CatchupETL, billing cron, and automation cron stay.

## What changed

When `enable_ecs_api` is **true**, Terraform destroys:

- `APIHandler` and `AIProxy`, including the public AI Proxy Function URL, its public invoke permissions, and the `/braintrust/<deployment>/ai-proxy-url` SSM parameter
- API Gateway, which existed only to invoke `APIHandler`
- the CloudFront origins for API Gateway and the AI Proxy Function URL (traffic is already on the ECS origin)

When `enable_ecs_api` is **false**, those resources stay. State addresses move from uncounted resources to `[0]` so the apply does not recreate them.

Loop Runtime already uses the private gateway or the CloudFront API URL, not the Function URL. Quarantine no longer falls back to the Function URL when `enable_ecs_api` is true. Set `quarantine_proxy_url`, or enable `use_private_gateway_quarantine_proxy`, if quarantine UDFs need an explicit proxy URL.

## Upgrade steps

1. Finish the [v6 ECS cutover](MIGRATION_V6.md) first. Leave `enable_ecs_api = false` until ECS is serving traffic.
2. Bump the module to v7 and apply with `enable_ecs_api` still `false` if you have not cut over. This only moves Lambda and API Gateway state to count indexes.
3. Set `enable_ecs_api = true` and apply. That apply deletes APIHandler, AIProxy, and API Gateway.

## Rollback

Setting `enable_ecs_api` back to `false` recreates APIHandler, AIProxy (including the public Function URL), and API Gateway.

Downgrading the module after an apply is not safe. The previous version addresses these resources without `[0]`, so a downgrade plan recreates the Lambdas and API Gateway.

## What stays

- QuarantineWarmupFunction and the quarantine functions it creates outside Terraform
- MigrateDatabaseFunction
- CatchupETL
- BillingCron
- AutomationCron
