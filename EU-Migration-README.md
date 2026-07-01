# API ECS — migration from the legacy `api-ecs` service

This module runs the Braintrust API on ECS Fargate. It is in the middle of a
migration from a **single legacy `api-ecs` service** to a **split set of
`braintrust-api*` services** (a general-purpose service plus dedicated ingest
and background services). The migration is designed to be additive and
reversible: nothing is destroyed during the cutover, and traffic can be flipped
forward and back with a single flag.

## The two service generations

| | Legacy | New |
|---|---|---|
| Defined in | `legacy-api-ecs.tf` | `braintrust-api.tf`, `braintrust-api-ingest.tf`, `braintrust-api-background.tf` |
| ECS services | `…-api-ecs` | `…-braintrust-api`, `…-braintrust-api-ingest`, `…-braintrust-api-background` |
| ALB target group | `…-api-ecs` | `…-api`, `…-api-ingest`, `…-api-bg` |
| Role | One service handles everything | Interactive traffic on `braintrust-api`; ingest paths (`/logs3`, OTel) and heavy background paths (evals, function invoke, proxy) split onto dedicated services via ALB path rules |

Both generations sit behind the **same internal ALB** (`…-api-ecs`) and the same
listener. Which generation actually receives traffic is decided entirely by
`enable_full_ecs_api` (see below).

## Traffic paths

There are two independent callers of the API, and both reach it through the ALB
once ECS is in play:

- **Brainstore (internal):** controlled by `enable_ecs_api`. When set, Brainstore
  is pointed at the ECS ALB URL (the `ecs-api-url` SSM parameter) instead of the
  AI proxy Lambda.
- **External API (customers):** controlled by `enable_full_ecs_api`. When set,
  CloudFront's API/proxy origins move from API Gateway + the AI proxy Lambda to
  the ECS ALB.

## The flags

All three are root-module variables. `create_ecs_api` and `enable_ecs_api` gate
*whether* ECS exists and whether Brainstore uses it; `enable_full_ecs_api` is the
*cutover* switch.

### `create_ecs_api` (default `false`)
Creates the ECS cluster and this module. With this release, that means **both**
the legacy `api-ecs` service **and** all three new `braintrust-api*` services are
created.

### `enable_ecs_api` (default `false`)
Points Brainstore at the ECS API (the ALB) instead of the AI proxy Lambda.
Requires `create_ecs_api`. This is independent of the external API path — it only
moves Brainstore's internal calls onto the ALB.

### `enable_full_ecs_api` (default `false`) — the cutover switch
Requires `create_ecs_api`. This is the only flag that decides which service
generation serves traffic:

- **`false`:** the ALB listener default action forwards to the **legacy
  `api-ecs`** target group and **no path rules** exist, so all ALB traffic
  (including Brainstore's, when `enable_ecs_api` is set) goes to legacy.
  CloudFront keeps using API Gateway + the AI proxy Lambda. The new
  `braintrust-api*` services are still created and kept **warm**, but receive
  **zero traffic**.
- **`true`:** the ALB listener default action moves to **`braintrust-api`**, the
  ingest/background **path rules** are added, and **CloudFront's** API/proxy
  origins move to the ECS ALB. Brainstore (same ALB URL) now lands on the new
  services.

Because the new services are always pre-created, flipping this flag is a near
instant, warm traffic flip in both directions.

### Behavior matrix

Assuming `create_ecs_api = true`:

| `enable_ecs_api` | `enable_full_ecs_api` | Brainstore → | External API (CloudFront) → | ALB serves |
|---|---|---|---|---|
| `false` | `false` | AI proxy Lambda | API Gateway + Lambda | legacy (idle unless Brainstore points at it) |
| `true`  | `false` | ECS ALB | API Gateway + Lambda | **legacy** |
| `true`  | `true`  | ECS ALB | **ECS ALB** | **new (`braintrust-api*`)** |

> The legacy `api-ecs` service on `main` only ever served **Brainstore's**
> internal traffic — external API traffic always went to Lambda. Keep that in
> mind when reasoning about load during the migration.

## Migration runbook — Prod-EU

Prod-EU is currently running the **legacy** ECS API configuration:
`create_ecs_api = true`, `enable_ecs_api = true`, `enable_full_ecs_api = false`
(on the pre-migration code, only the single `api-ecs` service exists).

### Step 1 — Adopt this release (no traffic change)

Point Prod-EU at this release with the flags **unchanged**
(`enable_full_ecs_api = false`).

`terraform apply` will **additively** create the three new `braintrust-api*`
services, their target groups, and their log groups. The legacy `api-ecs`
service is untouched and keeps serving all traffic; Brainstore still routes
through the ALB to legacy; CloudFront still uses Lambda.

Verify before continuing:
- The new ECS services reach steady state and their ALB target groups report
  **healthy** targets.
- The legacy `api-ecs` service shows no redeploy / no change.
- Application traffic and Brainstore are unaffected.

### Step 2 — Cut over

Set `enable_full_ecs_api = true` and `terraform apply`.

This flips the ALB listener default action to `braintrust-api`, adds the
ingest/background path rules, and moves CloudFront's API/proxy origins to the ECS
ALB. Because the new services are already warm, traffic moves with no cold-start
gap.

Verify:
- External API traffic and Brainstore queries succeed against the new services.
- Per-service metrics/logs show traffic landing on `braintrust-api`,
  `braintrust-api-ingest`, and `braintrust-api-background` as expected.

### Rollback

Set `enable_full_ecs_api = false` and `terraform apply`. This restores the exact
pre-cutover topology: CloudFront back on Lambda, ALB back on legacy. The new
services stay created and warm, so re-cutover is again instant.

### Step 3 — Decommission legacy (future release)

Once the new services are proven in Prod-EU, a follow-up release deletes
`legacy-api-ecs.tf` to tear down the legacy `api-ecs` service, target group,
autoscaling, and log group.

## Troubleshooting

### `Creation of service was not idempotent` on re-apply

If the first apply failed partway through (for example before the ALB listener
associated the new target groups), Terraform may **taint** the three
`braintrust-api*` ECS services while they still exist in AWS. The next plan
shows them as `+/-` (create-before-destroy) and apply fails because ECS refuses
to create a second service with the same name.

After pulling a release that includes the weighted-listener fix, **untaint** the
services so Terraform adopts the existing ones instead of replacing them:

```bash
terraform untaint 'module.braintrust-data-plane.module.api_ecs[0].aws_ecs_service.braintrust_api'
terraform untaint 'module.braintrust-data-plane.module.api_ecs[0].aws_ecs_service.braintrust_api_ingest'
terraform untaint 'module.braintrust-data-plane.module.api_ecs[0].aws_ecs_service.braintrust_api_background'
```

Adjust the module path if your root module name differs. Then re-run
`terraform apply`. The plan should show autoscaling resources being created and
no replacement of the ECS services.

## Sizing variables

The legacy and new services are sized independently, so you can tune them
separately during the migration.

- **Legacy:** the retained `api-ecs` service is sized via the root variables
  `api_ecs_cpu` / `api_ecs_memory` / `api_ecs_min_count` / `api_ecs_max_count` /
  `api_ecs_cpu_target_value` / `api_ecs_memory_target_value` (wired into the
  module's `legacy_api_ecs_*` inputs). These keep their pre-migration names and
  defaults, so an environment like Prod-EU that already sets them continues to
  apply with **no change** to the running legacy service.
- **New:** `braintrust_api_*`, `braintrust_api_ingest_*`, and
  `braintrust_api_background_*` (cpu, memory, min/max count, CPU and event-loop
  utilization targets).
