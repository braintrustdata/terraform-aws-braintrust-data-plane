# Migrating to v6

Upgrade this Terraform module **one major version at a time**. See the [README](README.md#major-versions) for the general upgrade policy, and the [routine upgrade guide](https://www.braintrust.dev/docs/admin/self-hosting/upgrade/routine) for the standard process of bumping the module version and applying Terraform.

v6 moves the primary APIHandler and AIProxy workloads from Lambda onto ECS. This is a major release and **requires a follow-up apply** to cut traffic over to ECS. Lambdas are being phased out in favor of ECS in all future releases.

## What changed

APIHandler and AIProxy now run as ECS services alongside the existing Lambdas. The ECS API is split into three services for different workload types:

- `braintrust-api` — general API traffic
- `braintrust-api-ingest` — ingestion paths (`/logs3`, `/otel/v1/traces`)
- `braintrust-api-background` — background paths (evals, function invoke, proxy)

These services have new variables that require consideration:
- `braintrust_api_extra_env_vars`
  - If you modified `service_extra_env_vars.APIHandler` or `service_extra_env_vars.AIProxy` you will need to duplicate those values here.
- `braintrust_api_version_override`
  - If for some reason you are locked onto a specific version of our services with `lambda_version_tag_override`, then you need to copy that here. 
- `braintrust_api_min_count` / `braintrust_api_max_count`
  - The defaults are 3 and 50 which is sensible for nearly all but the most high traffic deployments
- `braintrust_api_ingest_min_count` / `braintrust_api_ingest_max_count`
  - The defaults are 6 and 200
- `braintrust_api_background_min_count` / `braintrust_api_background_max_count`
  - The defaults are 3 and 50


## Upgrade steps

1. **Bump the module to v6** and apply Terraform with `enable_ecs_api` left at its default (`false`).

   This creates the ECS services, ALB, and related infrastructure. CloudFront continues to send traffic to Lambda. ECS and Lambda run side by side while ECS warms up.

   If you have customized `service_extra_env_vars` or `lambda_version_tag_override` then add them to your config (see Whats Changed above)

3. **Verify your Data Plane is still healthy**

   Terraform should have successfully applied without error. You should exercise the data plane with a few calls in the UI.

4. **Cut over traffic to ECS** by setting:

   ```hcl
   enable_ecs_api = true
   ```

   Apply again. CloudFront will route API traffic to the ECS ALB instead of API Gateway / Lambda.

5. **Verify the cutover** by exercising the data plane again (API requests, ingestion, evals).

## Rollback

Set `enable_ecs_api = false` and apply. CloudFront will revert to the Lambda path. This is a fast rollback while the Lambdas are still deployed.

## Cleanup

Lambda resources will continue to exist in your data plane, though they are no longer used. A future release will remove the Lambda resources.
