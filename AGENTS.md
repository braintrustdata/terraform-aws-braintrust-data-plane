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

### Do not name customers in public text

Do not mention named customers in PRs, comments, docs, examples, or commit messages. Refer to them generically (private dataplane, hybrid, residency-sensitive, etc.).

### Tag created AWS resources with the deployment name

When this module creates AWS resources, tag them with
`BraintrustDeploymentName = var.deployment_name` wherever the resource type
supports tags. In submodules, use `local.common_tags`. At the root, merge that
key with `local.all_custom_tags` (so APN tags stay). Skip resource types that
cannot be tagged.

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

### Review the inverse of every `count` / `for_each`

Traffic/cutover flags (`enable_ecs_api`, `enable_ai_gateway`, and similar) are meant to flip in both directions in a single apply. When adding a resource gated on such a flag:

- Mentally apply `true → false`. Terraform will destroy the resource in the same apply that stops referencing it.
- If AWS requires the parent to finish deploying that detach first, rollback fails. CloudFront origin request policies, cache policies, functions, and VPC origins are in this class — distribution updates are asynchronous, and CloudFront rejects deleting a still-attached child.
- Do not `count` a resource on a rollback-safe flag just to avoid an unused object. Keep it created (same lifetime as the parent module / sibling origin) and only gate *attachment*.
- `create_*` flags own resource lifetime; `enable_*` flags own routing.

### Private gateway ALB relocation

The gateway internal ALB lives in `modules/gateway-alb` so callers can reference `GATEWAY_URL` without depending on `gateway-ecs`. Temporary `moved` blocks in `moved_state.tf` remount state from `services_common` → `gateway_alb` so upgrades do not destroy/recreate the ALB. Remove those moved blocks after all stacks have applied once.

Whether an EKS gateway would reuse this ALB via Terraform is TBD — do not assume it.

### Private gateway: `create_ai_gateway` vs `enable_ai_gateway`

Similar two-step pattern to API ECS (`enable_ecs_api`), but gateway infra itself is still optional:
- **`create_ai_gateway`**: gateway ALB (`modules/gateway-alb`) and gateway ECS service (`modules/gateway-ecs`).
- **`enable_ai_gateway`**: wire `GATEWAY_URL` on APIHandler, AIProxy, and ECS API. Requires `create_ai_gateway`.

Use `create_ai_gateway = true` with `enable_ai_gateway = false` for a two-step prod cutover (stand up infra while keeping caller-supplied `GATEWAY_URL`, e.g. hosted gateway). Set both true for single-apply wiring on greenfield deployments.

### CloudFront VPC origin unsupported AZs

CloudFront rejects VPC origin create/update if the origin ALB spans an unsupported AZ (e.g. `use1-az3`), even when other ALB AZs are fine. This module filters ALB (+ matching ECS task) subnets to supported AZs for `ApiEcsOrigin` and private gateway origins. VPC AZ defaults stay on `aws_availability_zones.available` so existing `create_vpc` stacks do not ForceNew subnets/NAT on upgrade; greenfield VPCs may still contain a banned AZ, but ALBs simply omit it. In regions with an exclusion, those ALB-backed services therefore run across **2 AZs instead of 3** (resilience tradeoff for origin creatability).

Existing stacks that already have ALBs in a banned AZ are fixed by an in-place ALB subnet shrink, then origin create. VPC origin resources tag `AlbSubnetsApplied` with a post-apply ALB subnet fingerprint so Terraform cannot race origin create ahead of that shrink (ARN/DNS alone do not change when subnets change). The edge orders the SetSubnets API call before the origin operation; CloudFront's view of ALB AZs is eventually consistent, so a rare transient `ValidationException` on first apply may need a re-apply.

### Quarantine LLM proxy URL

Quarantine UDFs get proxy base URLs from API `getRuntimeEnv` via
`QUARANTINE_PROXY_URL`. Do **not** derive this from CloudFront
`*.cloudfront.net` / request Host headers (Terraform cycle with ingress,
header-spoof risk, and breaks ALB-only / GCP-style non-CF dataplanes).
Do **not** hairpin via the API ECS ALB (`/v1/proxy` on api-ts); do **not**
peer the quarantine VPC to main for this path. Prefer PrivateLink to the
private gateway when opted in. Loop Runtime stays on the AI Proxy Function
URL; PrivateLink only affects quarantine when the flag is on.

#### `use_private_gateway_quarantine_proxy` (default `false`)

Opt-in switch for dataplane-local quarantine → private gateway wiring via
**PrivateLink** (interim and preferred endgame vs VPC peering).
Default **false** so SaaS (including eu-prod's manual hosted URL) and
existing stacks are unchanged until operators explicitly enable it.

- **`false`**: do **not** auto-set from PrivateLink / private gateway; do
  **not** create the NLB→ALB endpoint sandwich. Use `quarantine_proxy_url`
  if set; otherwise the AI Proxy Lambda Function URL.
- **`true`**: requires `create_ai_gateway`. When `create_vpc` and the module
  quarantine VPC are both enabled, creates PrivateLink and sets
  `QUARANTINE_PROXY_URL` to `http://<vpce-dns>/v1/proxy` (unless override).
  No-ops PrivateLink when `use_global_ai_gateway_origin` is true. If the
  module cannot create PrivateLink (existing main VPC, existing quarantine
  VPC, or quarantine disabled) and `quarantine_proxy_url` is unset, apply
  fails. Adds an internal NLB (extra cost) in front of the gateway ALB.

#### URL precedence

1. `quarantine_proxy_url` override if set (e.g. eu-prod → SaaS EU API
   `/v1/proxy`, or GCP-style manual URLs) — **always wins**
2. else `http://<vpce-dns>/v1/proxy` when
   `use_private_gateway_quarantine_proxy` wires PrivateLink (module-managed
   VPCs; not `use_global_ai_gateway_origin`)
3. else AI Proxy Lambda Function URL

#### Networking (PrivateLink; only when the flag wires to private gateway)

Uses an NLB→ALB PrivateLink sandwich (`target_type = "alb"`):

1. **Provider (main VPC)**: internal multi-AZ NLB → target group
   `target_type = "alb"` attached to the gateway ALB → TCP **80** listener →
   `aws_vpc_endpoint_service` with `acceptance_required = false`
   (same-account). Gateway ALB SG allows HTTP from the NLB SG only —
   quarantine does **not** talk to the ALB directly.
2. **Consumer (quarantine VPC)**: interface VPC endpoint in quarantine
   private subnets; endpoint SG allows the quarantine Lambda SG on **:80**.
3. **URL**: `http://<vpce-dns>/v1/proxy` (VPCE DNS, not gateway ALB DNS).
   Plain HTTP on this hop is intentional: traffic stays inside AWS PrivateLink
   (quarantine VPCE → NLB → gateway ALB) and never crosses the public internet.
   TLS would require certs on the private ALB/NLB path without a customer DNS
   name; HTTP matches the private-ALB pattern used elsewhere in this module.

Automated only for **module-managed** main + quarantine VPCs
(`create_vpc` and `enable_quarantine_vpc` without `existing_quarantine_vpc_id`).
Existing VPC / existing quarantine / quarantine disabled: Terraform fails
unless you set `quarantine_proxy_url`, or `use_global_ai_gateway_origin` is
true (documented no-op; Function URL, no PrivateLink). For existing VPCs,
create an interface endpoint to
`quarantine_gateway_privatelink_service_name` (when the provider side exists
in a module-managed stack, or stand up equivalent NLB/service yourself) and
set `quarantine_proxy_url` to `http://<your-vpce-dns>/v1/proxy`.

**Cost / AZ notes**: PrivateLink adds an internal NLB (hourly + LCU) plus
interface endpoint hourly/GB charges. Place NLB and VPCE ENIs across the
same AZs as the gateway ALB subnets so the endpoint service is available in
those AZs; mismatched AZ coverage can yield unresolved or unhealthy
endpoints.

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
