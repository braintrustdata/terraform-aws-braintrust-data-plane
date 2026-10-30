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
│   ├── loop-runtime-alb/    # Loop Runtime internal ALB
│   ├── loop-runtime-ecs/    # Loop Runtime ECS service
│   ├── loop-runtime-sandbox-aws-microvm/ # Loop sandbox MicroVM network and image
│   ├── services/            # Lambda and ECS services
│   ├── services-common/     # Shared IAM, SGs, secrets (API/Brainstore/quarantine)
│   ├── storage/             # S3 buckets
│   ├── vpc/                 # VPC + subnets
│   └── remote-support/      # Optional remote support access
├── examples/
│   ├── braintrust-data-plane/          # Production example
│   ├── braintrust-data-plane-private/  # Private API ALB example
│   ├── braintrust-data-plane-sandbox/  # Sandbox/testing example
│   ├── braintrust-data-plane-external-eks-quarantine/
│   └── cloudfront-logging/
├── scripts/                 # Operational helper scripts
└── mise.toml                # Tool versions and tasks (terraform, tflint, uv)
```

### Key architecture concepts

- **Brainstore** has a reader/writer split — separate ASGs, instance types, and scaling. Both require EC2 instances with **local NVMe storage** (e.g., Graviton4 `m8gd`, `c8gd`, `r8gd`; Graviton3 `m7gd`, `c7gd`, `r7gd`; or `c5d`, `m5d`, `i3`, `i4i`). This is a hard requirement enforced by `postcondition` blocks on the `aws_ec2_instance_type` data sources. Families without local storage (`m8g`, `c8g`, `r8g`, `m7g`, `c7g`, `r7g`, `t3`, `m5`, `c5`) will fail at plan time.
Compatibility for Graviton5 instances is being validated.

**Quarantine VPC** is a separate VPC for running user-defined functions (scorers, tools) in network isolation. When enabled, a warmup Lambda creates ~30 functions across 9 runtimes **outside Terraform state**.
- **`deployment_name`** prefixes all resource names. Must be unique per deployment in the same AWS account (max 18 characters).

## Rules

### Start new infrastructure from existing module conventions

Before implementation, inspect the closest existing modules and root-module call sites.

- Do not implement until you identify precedents for every public input, network path, and shared-resource integration.
- List resource owners, security group directions, and managed or existing VPC paths before edits.
- Find at least two analogous implementations before you design a new interface.
- Match existing names, input shapes, defaults, module boundaries, tags, and resource ownership.
- Reuse established maps such as `authorized_security_groups` instead of parallel one-off inputs.
- Prefer explicit Terraform that a reviewer can follow over compact abstractions or generic indirection.
- Keep related resources beside their existing peers.
- Place new root module calls beside analogous calls. Use `main.tf` when that category already lives there.
- Place public root inputs in `variables.tf`.
- Do not create feature-specific root files solely for convenience when peers use a canonical location.
- Document every convention deviation in the PR before review.
- Treat an unexplained convention deviation as a review blocker.

### Optimize Terraform for human review

Readable Terraform and readable plans are product requirements.

- Use names that describe the resource purpose and owner.
- Keep data flow visible from root inputs through child modules.
- Prefer small explicit maps and locals over dependency tokens or hidden control inputs.
- Do not add inputs such as `service_dependency_ids` to force normal Terraform ordering.
- Let value references create dependencies.
- Use `depends_on` only for a real dependency that no value reference expresses.
- Do not add optional flags for resources that the enabled topology requires.
- Keep sensitive values in Secrets Manager and use native ECS secret injection.
- Do not place secret values in plaintext container environment lists.
- Keep task definition plans readable unless the provider itself hides the value.

### Use current security group resource patterns

- Create security groups with `aws_security_group`.
- Create new rules with `aws_vpc_security_group_ingress_rule` or `aws_vpc_security_group_egress_rule`.
- Do not add inline `ingress` or `egress` blocks to `aws_security_group`.
- Create one Terraform resource for each logical security group rule.
- Let the destination service module own its inbound rules.
- Pass source security group IDs into the destination module through an authorization map.
- Do not pass destination security group IDs into a source service module.
- Match the destination module's existing rule names, descriptions, tags, and map keys.
- Use security group references instead of CIDR rules for service-to-service access.
- Preserve a legacy rule type when the provider cannot migrate its live state safely.
- Do not mix rule types for style alone when that change requires replacement.

### Prefer private service connectivity

- Use private service connections for internal traffic whenever AWS supports them.
- Prefer direct private load balancers, VPC endpoints, or PrivateLink for cross-VPC traffic.
- Do not route internal traffic through public endpoints, CloudFront, or NAT without a service requirement.
- Keep a public path only when the application or AWS service requires it.
- Document the public-path requirement and its security controls.
- Restrict private listeners and endpoints to the exact caller security groups and ports.

### Support existing VPCs for every feature VPC

If a feature creates a VPC, also support a caller-provided VPC.

- Match the root module's existing VPC input convention.
- Use numbered private subnet inputs when equivalent root inputs are numbered.
- Do not introduce a subnet list for the same public concept.
- Require the same subnet count that the managed VPC creates.
- Verify that every supplied subnet belongs to the supplied VPC.
- Reject missing, empty, or duplicate subnet IDs.
- Keep managed-VPC and existing-VPC service behavior equivalent.
- Do not change routes or DNS controls in a caller-provided VPC unless the interface explicitly requests that change.
- Document which network controls remain the caller's responsibility.

### Design live-state migration before resource structure

- Determine whether a released module already owns each remote object.
- Preserve existing resource addresses when ownership does not change.
- Add `moved` blocks when a same-type resource changes address.
- Verify provider support before any cross-type `moved` block.
- Do not infer move support from a provider method or an unfinished state mover.
- Test the exact source schema, target type, and provider version.
- Do not replace live network rules only to use a newer Terraform resource type.
- Do not require manual state commands or multiple applies for a normal module upgrade.
- Test upgrades against representative live state before merge.

### Require design evidence before merge

- Compare each new module interface with its closest existing interface.
- Review both managed-resource and caller-provided-resource paths.
- Review every enabled and disabled flag path.
- Review the inverse of each `count` and `for_each` condition.
- Inspect a representative Terraform plan for readable resource changes.
- Verify that the plan does not replace unrelated resources.
- Add focused tests for ownership, network access, validation, and existing VPC behavior.
- Run `mise run lint` and `mise run validate` before merge.
- Do not merge until upgrade behavior and state moves are clear.

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

### Keep Managed BYOC quota targets above default capacity

`managed-byoc/quota-config.json` sets the quotas requested during onboarding. When you change a Fargate service's default task CPU or max count, or add a Fargate service, recompute the default-scale total. That's each service's max count × task vCPU, with optional services such as Loop runtime turned on. Keep the Fargate On-Demand vCPU target (`L-3032A538`) above that total, with headroom for rolling deployments, which briefly double a service's tasks. Do the same for the EC2 vCPU target (`L-1216C47A`) when Brainstore instance defaults change.

### `DANGER_`-prefixed variables are production safety toggles

Variables prefixed with `DANGER_` (e.g., `DANGER_disable_database_deletion_protection`) disable production guardrails. Never change their defaults to `true`. They should only appear set to `true` in the sandbox example, with a comment explaining the risk.

### `internal_observability_*` variables are Braintrust staff only

The `internal_observability_*` variables (Datadog API key, env name, region) are for internal Braintrust engineering use. Do not add them to customer-facing documentation, production examples, or sandbox examples.

### Custom CA bundle delivery

`custom_ca_bundle_secret_arn` references a Secrets Manager secret containing a PEM-encoded CA bundle. Keep the certificate value out of Terraform configuration and retrieve it at runtime.

- API ECS uses native ECS secret injection.
- Brainstore EC2 retrieves the secret in `user_data` and passes the exported multiline value to Docker with `--env BRAINTRUST_CUSTOM_CA_BUNDLE`. Do not place the multiline PEM in `/etc/brainstore.env`.
- When `custom_ca_bundle_kms_key_arn` is set, grant only `kms:Decrypt` for the supplied key and restrict it to Secrets Manager.
- Leave existing runtime behavior unchanged when these inputs are unset.

### Scripts use `uv` shebangs

Python scripts in `scripts/` use `#!/usr/bin/env -S uv run --script` with inline dependency metadata. This allows zero-setup execution without managing virtual environments. Do not replace these with plain `python3` shebangs or add `requirements.txt` files.

### In-place upgrades on existing deployments

Module changes must be applyable directly to live customer stacks without tear-down or multi-phase hacks. When restructuring resources:

- Add `moved` blocks to `moved_state.tf` instead of taint/recreate when restructuring resources that customers have in state (see existing brainstore and ingress moves).
- Avoid env-only changes on Lambdas that do not need them — e.g. do not merge shared env into `MigrateDatabaseFunction` or crons, because that publishes a new Lambda version and re-invokes migrations.
- Prefer state moves and in-place updates over replace; if a resource must be replaced, document why and whether downtime is expected.

### Bump major when downgrade-after-apply is unsafe

Some Terraform changes apply forward in place (`moved` blocks, new resource keys, gapped priorities) but a revert or module downgrade after apply **recreates live resources**. Example: ALB listener rules fall through to the default target group. Do not hide these in a patch.

Spot these:
- Changing `for_each` / `count` identity (index keys → stable keys)
- `moved` blocks (often in `moved_state.tf`) that exist so apply is in-place
- Replacing resource addresses that AWS will treat as destroy+create
- Listener rule priorities or names that collide on rollback
- State identity changes where `terraform plan` on the previous module version after apply would destroy load balancer rules, endpoint services, databases, or similar

Call this out in the PR. Bump **major** (preferred). If a major is truly wrong, bump at least **minor** and say why rollback is unsafe in the GitHub release notes. This repo has no CHANGELOG; versions are git tags (`v6.6.0`) and GitHub Releases via `.github/workflows/create-release.yml`. For a major, add or update `MIGRATION_V*.md` and the Major versions section in `README.md`.

### Review the inverse of every `count` / `for_each`

Traffic/cutover flags (`enable_ecs_api`, `enable_ai_gateway`, and similar) are meant to flip in both directions in a single apply. When adding a resource gated on such a flag:

- Mentally apply `true → false`. Terraform will destroy the resource in the same apply that stops referencing it.
- If AWS requires the parent to finish deploying that detach first, rollback fails. CloudFront origin request policies, cache policies, functions, and VPC origins are in this class — distribution updates are asynchronous, and CloudFront rejects deleting a still-attached child.
- Do not `count` a resource on a rollback-safe flag just to avoid an unused object. Keep it created (same lifetime as the parent module / sibling origin) and only gate *attachment*.
- `create_*` flags own resource lifetime; `enable_*` flags own routing.
  Exception: `enable_ecs_api` also owns the lifetime of APIHandler, AIProxy, the public Function URL, and API Gateway. Setting it back to false creates that surface again, including a new Function URL hostname. It does not resume a warm standby. A Lambda-mode upgrade only moves state to `[0]`; Terraform moves surviving `[0]` resources back on downgrade. Resources deleted by an ECS-mode apply are created again on downgrade. On v7 the default is true. Set `enable_ecs_api = false` to keep customer traffic on Lambda. On v6 the default was false.

### Private gateway ALB relocation

The gateway internal ALB lives in `modules/gateway-alb` so callers can reference `GATEWAY_URL` without depending on `gateway-ecs`. Temporary `moved` blocks in `moved_state.tf` remount state from `services_common` → `gateway_alb` so upgrades do not destroy/recreate the ALB. Remove those moved blocks after all stacks have applied once.

Whether an EKS gateway would reuse this ALB via Terraform is TBD — do not assume it.

### Private gateway: `create_ai_gateway` vs `enable_ai_gateway`

Upgrade an existing deployment with [MIGRATION_V7.md](MIGRATION_V7.md). Finish the v6 applies first.

`enable_ecs_api`, `create_ai_gateway`, `enable_ai_gateway`, and `use_private_ai_gateway_origin` default to `true`. A new stack that sets nothing gets ECS ingress and the private gateway. Set `enable_ecs_api = false` to keep customer traffic on Lambda. The gateway flags still default to `true`, so that is Lambda ingress plus the private gateway. A gateway already built but not enabled must keep `create_ai_gateway = true` and set `enable_ai_gateway` and `use_private_ai_gateway_origin` to `false`. See [MIGRATION_V7.md](MIGRATION_V7.md). On v6 an omitted `enable_ecs_api` means Lambda. On v7 an omitted `enable_ecs_api` means ECS. Existing deployments finish the v6 applies before this upgrade. People who already cut over can leave `enable_ecs_api = true` or drop it.

- **`create_ai_gateway`**: gateway ALB (`modules/gateway-alb`) and gateway ECS service (`modules/gateway-ecs`). Loop→gateway ALB SG ingress is also opened when Loop exists.
- **`enable_ai_gateway`**: wire `GATEWAY_URL` on APIHandler and AIProxy when those Lambdas exist, and on ECS API, and `LOOP_RUNTIME_AI_PROXY_URL` on Loop ECS. Requires `create_ai_gateway`.

External EKS ignores `enable_ecs_api` and the gateway flags. Helm owns the gateway.

### Private data plane mode

`enable_private_dataplane = true` serves customer requests through the internal API ALB without CloudFront or API Gateway.
Private mode requires these inputs:

- `enable_ecs_api = true`.
- `create_ai_gateway = true`.
- `enable_ai_gateway = true`.
- `braintrust_api_alb_custom_domain` and `braintrust_api_alb_certificate_arn`.

Private mode supports managed, existing, and mixed main/quarantine VPCs through the standard VPC and subnet inputs.
The caller controls client connectivity, DNS, and network controls in supplied VPCs.
Private mode rejects external EKS, hosted gateway flags, and an explicit `quarantine_proxy_url`.
It also rejects the CloudFront inputs `custom_domain`, `custom_certificate_arn`, and `waf_acl_id`.
`use_private_ai_gateway_origin` has no effect because CloudFront is absent.

The customer listener uses HTTPS port 443.
Service callbacks use the ALB AWS hostname on HTTP port 8000 through explicit service security groups.
Both listeners route `/v1/proxy` and `/v1/proxy/*` directly to gateway tasks.
With Loop enabled, both listeners route `/loop/runtime` and `/loop/runtime/*` directly to Loop tasks.
Private mode forces the gateway callback URL through `OVERRIDE_BRAINTRUST_API_URL`.
Organization authentication does not replace that URL.

Private mode automatically creates quarantine PrivateLink when quarantine is enabled, even with `use_private_gateway_quarantine_proxy = false`.
With quarantine disabled, the default flag creates no quarantine endpoint.
An explicit `use_private_gateway_quarantine_proxy = true` fails validation when quarantine is disabled in private mode.
Private mode retains outbound access requirements for AWS services, model providers, and other dependencies.
Transitions between public and private mode cause an outage and delete or recreate CloudFront.
The [private example README](examples/braintrust-data-plane-private/README.md) describes the client setup and request paths.

### Quarantine LLM proxy URL

Quarantine UDFs receive proxy base URLs from API `getRuntimeEnv` through `QUARANTINE_PROXY_URL`.
API ECS selects the URL in this order:

1. An explicit `quarantine_proxy_url` override. Private mode rejects this override.
2. The module-created PrivateLink URL, `http://<vpce-dns>/v1/proxy`.
3. The AI Proxy Lambda Function URL while that function exists.
4. The CloudFront API URL with `/v1/proxy` in public ECS mode.

Public mode uses PrivateLink when `use_private_gateway_quarantine_proxy = true`, quarantine is enabled, and `use_global_ai_gateway_origin = false`.
Private mode automatically uses PrivateLink when quarantine is enabled.
An explicit URL override does not suppress resource creation in public mode.
APIHandler Lambda does not receive automatic URL injection from this flag.
External EKS rejects `use_private_gateway_quarantine_proxy = true`. Helm owns its gateway and application configuration.

Public fallbacks require quarantine HTTPS egress.
A managed quarantine VPC uses its own NAT gateway.
CloudFront serves `/v1/proxy` from the configured hosted gateway, private gateway, or API ECS origin.
With the hosted gateway origin, quarantine LLM requests leave the data plane.
A CloudFront WAF or source-IP allowlist must admit the quarantine egress address for that public path.
The URL presence check does not test egress, WAF admission, or authentication.

Do not derive `QUARANTINE_PROXY_URL` from a request Host header.
Do not use the main VPC API ALB or gateway ALB hostname directly for quarantine calls.
Do not peer quarantine to the main VPC for this path.

The main VPC ALBs do not provide direct access from the isolated quarantine VPC.
PrivateLink provides the private connection between these VPCs.
An absent `QUARANTINE_PROXY_URL` in the ECS configuration falls back to `http://localhost:8000/v1/proxy`, which quarantine Lambdas cannot reach.
Loop uses the private gateway when `enable_ai_gateway = true`.
The hosted gateway or CloudFront fallback applies only in public mode when that gateway is disabled.

#### `use_private_gateway_quarantine_proxy` (default `false`)

This flag selects quarantine PrivateLink in public mode.
It does not disable the automatic PrivateLink path in private mode.
The default remains `false`.

- In public mode, `false` retains the explicit URL, AI Proxy Function URL, or CloudFront fallback.
- `true` requires `create_ai_gateway`.
- With quarantine enabled and the global origin disabled, `true` creates PrivateLink and selects its URL unless an override exists.
- With the global origin enabled, `true` skips PrivateLink and endpoint URL selection.
- With quarantine disabled and the global origin disabled, `true` requires an explicit `quarantine_proxy_url`.

#### PrivateLink network path

The module creates these resources in managed, existing, and mixed main/quarantine VPCs:

1. An endpoint service in the main VPC with same-account access and `acceptance_required = false`.
2. An internal NLB with a TCP port 80 listener and an ALB target group for the gateway ALB.
3. An interface endpoint in quarantine private subnets with HTTP port 80 access from the quarantine Lambda security group.

The gateway ALB admits HTTP from the NLB security group.
Quarantine does not connect directly to the gateway ALB.
The URL uses the endpoint DNS name: `http://<vpce-dns>/v1/proxy`.
This HTTP path stays inside AWS PrivateLink and uses the existing gateway ALB listener.
The endpoint waits for gateway ECS and its network path before it supplies the URL.
The gate checks service startup, not authenticated inference across the complete PrivateLink path.

Both VPCs must reside in the provider account and region.
Subnet IDs must be nonempty and distinct, belong to their respective VPCs, and span distinct availability zones.
Every quarantine endpoint availability zone must exist on the main VPC NLB.
Resource-derived IDs can defer validation until apply.
The caller controls routes, network ACLs, and DNS in existing VPCs.

Preserve the released root resource addresses, including the root-owned gateway ALB ingress rule.
Verify both managed and existing VPC paths.

The root-owned ingress rule is an existing exception to destination module ownership.
It is not a pattern for new rules.
PrivateLink adds NLB and interface endpoint charges.
It covers quarantine LLM requests, not other user-code calls or client access.

#### Public-mode compatibility and downgrade

Existing public-mode callers with the flag enabled and an explicit URL now create PrivateLink resources in supplied VPCs.
The explicit URL still takes precedence.
In public mode, `false` creates no PrivateLink resources.
In private mode, `false` retains PrivateLink while quarantine is enabled.

Before a public-mode PrivateLink cutover to a fallback, verify that the fallback is reachable.
For public deployments, disable PrivateLink on a compatible version before a downgrade without existing VPC support.

A private deployment requires a coordinated transition to public mode before it can use that public fallback.
`use_private_gateway_quarantine_proxy = false` alone cannot disable quarantine PrivateLink in private mode.

### Upgrade Sequencing (for customers upgrading from pre-2.0)

These constraints apply to customers migrating from Data Plane 1.x to 2.0. New deployments on 2.0+ ship with WAL v3 and no-PG defaults baked in.

- **Never set `skip_pg_for_brainstore_objects` on Data Plane versions before 2.0.** A known bug on 1.1.32 was fixed in the 2.0 images. The correct upgrade sequence is: 1.1.32 -> WAL v1 -> 2.0 + WAL v3 -> no-PG.
- **`brainstore_wal_footer_version` must be set in a separate apply after all Brainstore nodes are running the target version.** Old nodes cannot read the new WAL format during rollout. Exception: bumping v1 to v3 can be done in the same apply as the 2.0 image upgrade because all 2.0 nodes understand v3.
- **`skip_pg_for_brainstore_objects` is a one-way operation.** Once enabled for an object type, it cannot be rolled back without downtime.

### WAL_USE_EFFICIENT_FORMAT Decoupling

`BRAINSTORE_WAL_USE_EFFICIENT_FORMAT` is intentionally derived from EITHER `brainstore_wal_footer_version` OR `skip_pg_for_brainstore_objects` being set. This enables efficient format as early as possible in the upgrade sequence (when WAL v1 is set) rather than waiting for no-PG. Do not "simplify" this to only check one condition.

### Route changes in public and private modes

Public mode uses CloudFront as the frontend.
Private mode uses the API ECS ALB as the frontend and omits CloudFront.
A change to CloudFront alone does not update private ingress.
An unmatched ALB request reaches the default API target group, which can hide an incorrect route.

For every path or method change, review both public and private modes.
Update each affected route definition in this table.

| Route definition | Scope |
| --- | --- |
| `modules/ingress/cloudfront.tf` | Public origins and cache behaviors for API, functions, proxy, and Loop requests. |
| `modules/ingress/api-gateway-openapi-spec.tf` | Public Lambda ingress paths and methods. |
| `modules/api-ecs/alb-path-routes.tf` | API, ingest, and background routes, plus private gateway and Loop routes. |

Private mode uses two listeners on the same API ALB: customer HTTPS port 443 and internal HTTP port 8000.
The shared `alb_path_listener_rules` map supplies service routes to both listeners.
Private gateway and Loop rules also exist on both listeners.
Private mode excludes two public proxy routes from the shared map because the gateway rules handle those paths.

- Preserve the correct destination for each affected path in both modes.
- Review exact paths, descendant paths, HTTP methods, and rule precedence.
- Verify OPTIONS requests, streaming responses, and WebSocket upgrades when the endpoint uses them.
- Keep the customer listener and internal listener consistent for each applicable route.
- Preserve stable `METHOD:path` keys and existing priorities.
- Use unused priority gaps for new rules.
- Add focused route assertions for both modes and each affected optional service.
- Run the affected Terraform tests, including `tests/private_dataplane_api.tftest.hcl` for private listener changes.
- Recompute the ALB rule counts below after each route change.

### API ALB rule capacity

AWS defaults to 100 nondefault rules per ALB, across all listeners.
This quota is adjustable.
A second listener does not supply another 100 rules.
Default listener actions do not count toward this quota.
These are rule limits, not a limit on the number of application endpoints behind a default action.

The [AWS ALB quotas](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-limits.html) also limit condition values and match evaluations to five per rule.
The [condition documentation](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/rule-condition-types.html) permits up to three match evaluations per condition.
A method condition consumes a match evaluation as well as the path condition.
A path pattern can contain up to 128 characters.
These limits prevent arbitrary combinations of paths in one rule.

Current counts from `modules/api-ecs/alb-path-routes.tf`, reviewed on October 28, 2026:

| Mode | Customer listener rules | Internal listener rules | Total nondefault rules | Space under default quota |
| --- | ---: | ---: | ---: | ---: |
| Public, with or without Loop | 21 | 0 | 21 | 79 |
| Private, Loop disabled | 20 | 20 | 40 | 60 |
| Private, Loop enabled | 21 | 21 | 42 | 58 |

Public mode has 21 shared service rules.
Private mode excludes two public proxy rules and retains 19 shared service rules per listener.
Each private listener also has one gateway rule and, with Loop enabled, one Loop rule.
Each gateway or Loop rule contains two path values, but counts as one rule.
A new shared service route adds one public rule or two private rules across both listeners.
These counts describe the module configuration, not a live AWS deployment or its approved quota.

Before a route expansion, verify the deployment quota through Service Quotas or `aws elbv2 describe-account-limits`.
Count all nondefault rules on the same ALB, including rules outside this module.
Leave capacity for temporary rules during a migration.
Verify per-condition and per-rule limits before paths share a rule.
Do not broaden a wildcard solely to reduce the rule count.

### API Gateway Route Allowlist

`modules/ingress/api-gateway-openapi-spec.tf` defines the permitted paths and methods for the public Lambda ingress path.
A route absent from that specification returns 403 through API Gateway.
Browsers can report a CORS error because that response lacks CORS headers.
Private mode and public ECS mode do not use API Gateway.

## Development

Tool versions are managed via `mise.toml`:

```bash
mise install        # Install terraform, tflint, uv, pre-commit
mise run setup      # Install pre-commit hooks, init tflint
mise run lint       # terraform fmt + tflint
mise run validate   # terraform init + validate (module + production example)
```

Pre-commit hooks and `tflint` run automatically on commit. Run `mise run lint` to check before committing.
