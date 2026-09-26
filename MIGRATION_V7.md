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

Quarantine UDFs do not. On v6 they used the AI Proxy Function URL, reached through the quarantine VPC's NAT gateway. v7 removes that URL. If `enable_quarantine_vpc` is true, the apply fails unless `quarantine_proxy_url` is set or `use_private_gateway_quarantine_proxy` has created a PrivateLink URL. `use_global_ai_gateway_origin` does not set `QUARANTINE_PROXY_URL`; it only changes where CloudFront sends `/v1/proxy`. Leaving the variable unset makes api-ts hand the quarantine Lambda `http://localhost:8000/v1/proxy`, which that Lambda cannot call.

## Upgrade steps

1. Finish the [v6 ECS cutover](MIGRATION_V6.md) if this deployment should run on ECS. That cutover is `enable_ecs_api = true` on v6, while APIHandler and AIProxy still exist.
2. If quarantine is enabled, set a proxy the quarantine functions can reach and apply **on v6**, before the bump:
   - `quarantine_proxy_url = "https://<api domain>/v1/proxy"` when the quarantine VPC has internet egress. A module-managed quarantine VPC does: it uses the same NAT gateway as the main VPC. In ECS mode CloudFront already sends `/v1/proxy` to the API, and the UDF already carries an API key.
   - `use_private_gateway_quarantine_proxy` with `create_ai_gateway` when this module creates both VPCs and the private path is what you want.
   - A quarantine VPC you supply (`existing_quarantine_vpc_id`) may have no internet egress. A public URL will not work then. See [Existing VPCs](#existing-vpcs).
3. Bump to v7.
   - Already on ECS (`enable_ecs_api = true`): apply deletes APIHandler, AIProxy, and API Gateway.
   - Still on Lambda: keep `enable_ecs_api = false` for this apply. It only moves Lambda and API Gateway state to count indexes. A later apply that sets `enable_ecs_api = true` deletes them, and must include the quarantine proxy from step 2.

## Existing VPCs

`use_private_gateway_quarantine_proxy` creates PrivateLink only when this module creates both the main VPC and the quarantine VPC. If you supply either VPC, the module creates no PrivateLink resources and `quarantine_gateway_privatelink_service_name` is null.

On v6 those deployments still reached models through the public AI Proxy Function URL. The same public path still works when the quarantine VPC has internet egress: set `quarantine_proxy_url` to `https://<api domain>/v1/proxy`. The module does not choose that URL itself, because ingress and API ECS would depend on each other.

A customer-supplied quarantine VPC may have no internet egress. The module cannot tell. A public URL will not work in that case. Stand up a network load balancer, endpoint service, and quarantine interface endpoint yourself, and set `quarantine_proxy_url` to `http://<vpce-dns>/v1/proxy`. Do not point that URL at the API ECS load balancer or the gateway load balancer. Those are private to the main VPC. Apply the URL on v6, then bump.

## Rollback

Setting `enable_ecs_api` back to `false` recreates APIHandler, AIProxy (including a new public Function URL hostname), provisioned concurrency, and API Gateway. It is not a CloudFront-only flip. Brainstore's AI proxy SSM selector also changes back to the bare `/braintrust/<deployment>/ai-proxy-url` name in that same apply, while the parameter is being recreated. Replacement Brainstore instances can boot before the parameter exists.

Downgrading the module after an apply is not safe. The previous version addresses these resources without `[0]`, so a downgrade plan recreates the Lambdas and API Gateway.

## What stays

- QuarantineWarmupFunction and the quarantine functions it creates outside Terraform
- MigrateDatabaseFunction
- CatchupETL
- BillingCron
- AutomationCron
