# Braintrust AWS Data Plane — Terraform Module

This is a Terraform module that deploys the Braintrust hybrid data plane on AWS. It is used by Braintrust customers to run their data plane infrastructure in their own AWS accounts.

## Module Structure

```
├── main.tf, variables.tf, outputs.tf   # Root module — orchestrates submodules
├── modules/
│   ├── brainstore-ec2/      # Brainstore reader/writer ASGs (EC2 with local NVMe)
│   ├── database/            # RDS Postgres
│   ├── ecs/                 # ECS cluster
│   ├── elasticache/         # Redis (ElastiCache)
│   ├── gateway-alb/         # Private gateway internal ALB (ALB / TG / listener)
│   ├── gateway-ecs/         # LLM Gateway (ECS Fargate)
│   ├── ingress/             # CloudFront + API Gateway
│   ├── kms/                 # Encryption keys
│   ├── services/            # Lambda and ECS services
│   ├── services-common/     # Shared IAM, SGs, secrets (API/Brainstore/quarantine)
│   ├── storage/             # S3 buckets
│   ├── vpc/                 # VPC + subnets
│   └── remote-support/      # Optional remote support access
├── examples/
│   ├── braintrust-data-plane/          # Production example
│   ├── braintrust-data-plane-sandbox/  # Sandbox/testing example
│   ├── braintrust-data-plane-external-eks-quarantine/
│   └── cloudfront-logging/
├── scripts/                 # Operational helper scripts
└── mise.toml                # Tool versions and tasks (terraform, tflint, uv)
```

### Key architecture concepts

- **Brainstore** has a reader/writer split — separate ASGs, instance types, and scaling. Both require EC2 instances with **local NVMe storage** (e.g., `c8gd`, `c5d`, `m5d`, `i3`, `i4i`). This is a hard requirement enforced by `postcondition` blocks on the `aws_ec2_instance_type` data sources. Generic families (`t3`, `m5`, `c5`) will fail at plan time.
**Quarantine VPC** is a separate VPC for running user-defined functions (scorers, tools) in network isolation. When enabled, a warmup Lambda creates ~30 functions across 9 runtimes **outside Terraform state**.
- **`deployment_name`** prefixes all resource names. Must be unique per deployment in the same AWS account (max 18 characters).

## Rules

### Keep examples in sync with variables

When adding, removing, or renaming variables in the root module's `variables.tf`, update the example `main.tf` files to reflect the change. All examples under `examples/` should remain valid and representative.

### `DANGER_`-prefixed variables are production safety toggles

Variables prefixed with `DANGER_` (e.g., `DANGER_disable_database_deletion_protection`) disable production guardrails. Never change their defaults to `true`. They should only appear set to `true` in the sandbox example, with a comment explaining the risk.

### `internal_observability_*` variables are Braintrust staff only

The `internal_observability_*` variables (Datadog API key, env name, region) are for internal Braintrust engineering use. Do not add them to customer-facing documentation, production examples, or sandbox examples.

### Scripts use `uv` shebangs

Python scripts in `scripts/` use `#!/usr/bin/env -S uv run --script` with inline dependency metadata. This allows zero-setup execution without managing virtual environments. Do not replace these with plain `python3` shebangs or add `requirements.txt` files.

### In-place upgrades on existing deployments

Module changes must be applyable directly to live customer stacks without tear-down or multi-phase hacks. When restructuring resources:

- Add `moved` blocks to `moved_state.tf` instead of taint/recreate when restructuring resources that customers have in state (see existing brainstore and ingress moves).
- Avoid env-only changes on Lambdas that do not need them — e.g. do not merge shared env into `MigrateDatabaseFunction` or crons, because that publishes a new Lambda version and re-invokes migrations.
- Prefer state moves and in-place updates over replace; if a resource must be replaced, document why and whether downtime is expected.

### Private gateway ALB relocation

The gateway internal ALB lives in `modules/gateway-alb` so callers can reference `GATEWAY_URL` without depending on `gateway-ecs`. Temporary `moved` blocks in `moved_state.tf` remount state from `services_common` → `gateway_alb` so upgrades do not destroy/recreate the ALB. Remove those moved blocks after all stacks have applied once.

Whether an EKS gateway would reuse this ALB via Terraform is TBD — do not assume it.

### Private gateway: `create_ai_gateway` vs `enable_ai_gateway`

Similar two-step pattern to API ECS (`enable_ecs_api`), but gateway infra itself is still optional:
- **`create_ai_gateway`**: gateway ALB (`modules/gateway-alb`) and gateway ECS service (`modules/gateway-ecs`).
- **`enable_ai_gateway`**: wire `GATEWAY_URL` on APIHandler, AIProxy, and ECS API. Requires `create_ai_gateway`.

Use `create_ai_gateway = true` with `enable_ai_gateway = false` for a two-step prod cutover (stand up infra while keeping caller-supplied `GATEWAY_URL`, e.g. hosted gateway). Set both true for single-apply wiring on greenfield deployments.

### Quarantine LLM proxy URL

Quarantine UDFs get `QUARANTINE_PROXY_URL` from API ECS (via `getRuntimeEnv`). Do not point that at the private gateway ALB DNS (would require quarantine→main VPC access). Default selection:

- `quarantine_proxy_url` override if set
- else AI Proxy Lambda Function URL when `enable_ecs_api` is false
- else hosted gateway when `use_global_ai_gateway_origin` is true
- else `https://<custom_domain>/v1/proxy` (dataplane CloudFront hairpin; works with private gateway origin)

Avoid feeding `module.ingress.api_url` into API ECS — that creates an `api_ecs → ingress → api_ecs` cycle. `custom_domain` is a known input and breaks the cycle.

### Upgrade Sequencing (for customers upgrading from pre-2.0)

These constraints apply to customers migrating from Data Plane 1.x to 2.0. New deployments on 2.0+ ship with WAL v3 and no-PG defaults baked in.

- **Never set `skip_pg_for_brainstore_objects` on Data Plane versions before 2.0.** A known bug on 1.1.32 was fixed in the 2.0 images. The correct upgrade sequence is: 1.1.32 -> WAL v1 -> 2.0 + WAL v3 -> no-PG.
- **`brainstore_wal_footer_version` must be set in a separate apply after all Brainstore nodes are running the target version.** Old nodes cannot read the new WAL format during rollout. Exception: bumping v1 to v3 can be done in the same apply as the 2.0 image upgrade because all 2.0 nodes understand v3.
- **`skip_pg_for_brainstore_objects` is a one-way operation.** Once enabled for an object type, it cannot be rolled back without downtime.

### WAL_USE_EFFICIENT_FORMAT Decoupling

`BRAINSTORE_WAL_USE_EFFICIENT_FORMAT` is intentionally derived from EITHER `brainstore_wal_footer_version` OR `skip_pg_for_brainstore_objects` being set. This enables efficient format as early as possible in the upgrade sequence (when WAL v1 is set) rather than waiting for no-PG. Do not "simplify" this to only check one condition.

### API Gateway Route Allowlist

`modules/ingress/api-gateway-openapi-spec.tf` is an explicit allowlist of every permitted path and method. Any application route not in this spec returns 403 on hybrid deployments. Browsers report this as a misleading CORS error because the 403 response lacks CORS headers.

## Development

Tool versions are managed via `mise.toml`:

```bash
mise install        # Install terraform, tflint, uv, pre-commit
mise run setup      # Install pre-commit hooks, init tflint
mise run lint       # terraform fmt + tflint
mise run validate   # terraform init + validate (module + production example)
```

Pre-commit hooks and `tflint` run automatically on commit. Run `mise run lint` to check before committing.
