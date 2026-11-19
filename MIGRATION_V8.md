# Migrating to v8

Upgrade this Terraform module **one major version at a time**. See the [README](README.md#major-versions) for the general upgrade policy, and the [routine upgrade guide](https://docs.braintrust.dev/admin/self-hosting/upgrade/routine) for the standard process of bumping the module version and applying Terraform.

**Note** - This guide is still growing. These sections cover the starting version, the tooling requirement, the IAM move and what the upgrade plan shows so far. Later v8 changes add their own sections.

## Start from v7.3.0 or later

Upgrade to v7.3.0 or a later v7 release, and apply it, before you move to v8. v7.3.0 is the oldest release we support upgrading from. Coming from an older v7 release puts the v7.3.0 changes into the same apply as v8, and we don't support that combination.

## Terraform 1.17 or newer

The root module and the examples require Terraform `>= 1.17.0`, and the module is validated on Terraform 1.17.2. We didn't look for a lower minimum. Child modules under `modules/` keep `>= 1.10.0`.

v7 allows Terraform `>= 1.10.0`, so you can move every pipeline that applies this module to Terraform 1.17 while you're still on v7. Do that first. Then the v8 apply is the only change in that pipeline.

If you run Atlantis or a similar tool, check two settings before you upgrade: the Terraform version the tool runs (for example `terraform_version` in `atlantis.yaml`) and the `required_version` in your own configuration. Either one can still be pinned below 1.17, and either one stops the plan.

### OpenTofu

OpenTofu is still supported. The root module and each example have a `versions.tofu` that requires OpenTofu `>= 1.13`, and OpenTofu reads that file instead of `versions.tf`. We validate the module and the examples with `tofu validate` on OpenTofu 1.13, and that is all. The upgrade test needs Terraform's `state_key`, which OpenTofu doesn't have, so nobody has run an OpenTofu upgrade against mocked or real state. Plan an OpenTofu upgrade on a copy of your state first.

## What changes on apply

The upgrade plan from v7.3.0 or later shows two kinds of change. Treat anything outside these lists as a reason to stop.

### IAM moves into `modules/iam`

v8 moves the module's IAM into a child module, `modules/iam`, so that a security team can later run it on its own. Managed stacks keep the same roles, names, trust documents, permissions and physical resources. The root module's `moved_state.tf` has a `moved` block for each resource, so these moves update state and nothing in AWS. The plan shows them as moves with no change. They don't republish a Lambda function, register a task definition revision or rerun the database migration.

This release moves these roles and the policies and attachments that belong to them.

| Role | Name | Old address | New address |
| --- | --- | --- | --- |
| RDS enhanced monitoring | `<deployment_name>-db-monitoring` | `module.database.aws_iam_role.db_monitoring` | `module.iam.aws_iam_role.db_monitoring[0]` |
| Brainstore deployment waiter | `<deployment_name>-brainstore-deployment` | `module.brainstore_deployment[0].aws_iam_role.waiter` | `module.iam.aws_iam_role.brainstore_deployment_waiter[0]` |
| API ECS task execution | `<deployment_name>-api-ecs-task-exec` | `module.api_ecs[0].aws_iam_role.task_execution` | `module.iam.aws_iam_role.api_ecs_task_execution[0]` |
| Gateway task execution | `<deployment_name>-gateway-task-exec` | `module.gateway_ecs[0].aws_iam_role.task_execution` | `module.iam.aws_iam_role.gateway_task_execution[0]` |
| Gateway task | `<deployment_name>-gateway-task` | `module.gateway_ecs[0].aws_iam_role.task` | `module.iam.aws_iam_role.gateway_task[0]` |

The gateway Terraform files also split into `security-groups.tf` and `cloudwatch.tf` inside `modules/gateway-ecs`. That's a file move only, and no addresses change.

### Braintrust service versions

The module pins Braintrust service versions, so if your v7 release pins an older version than this one, the upgrade also moves your services. Expect new task definition revisions for the API ECS services and the gateway, new Lambda versions, a Brainstore instance refresh and that version's database migrations. These aren't part of the IAM moves. To keep them out of the v8 apply, set the `*_version_override` inputs to the version you run now, as [MIGRATION_V7.md](MIGRATION_V7.md#v730-iam-ownership-tag) describes, and remove them in a later apply.

## Rollback

**Rolling back to v7 after the v8 apply isn't supported.** v7 has no `moved` blocks for the `module.iam` addresses. A v7 plan on v8 state destroys the moved IAM at the new addresses and creates it again at the old ones.

The create runs while the role still exists, because the destroy of the new address hasn't finished. AWS rejects a second role with the same name, so the apply will likely fail partway with `EntityAlreadyExists` and need a second apply once the destroys complete. The recreated roles also have new unique IDs. Until the second apply succeeds, you can expect:

- RDS enhanced monitoring stops, because the monitoring role is missing or has no policy attachment.
- ECS tasks can't pull secrets, so new API and gateway tasks fail to start and replacements stall.
- The gateway task loses the credentials it uses to assume roles in your account, so Bedrock calls through the gateway fail.
- The Brainstore deployment waiter can't start a rollout.

We won't ship a v7.x patch that reverses the moves.

If an apply fails partway, fix the cause and apply v8 again. Don't pin v7. Before you upgrade, back up your state and confirm that the state backend has versioning turned on.

Restoring a v7 state backup doesn't get you back either. The v8 apply creates the Brainstore license secret, `${deployment_name}/brainstore/license-key`, and newer task definition and launch template versions. A restored v7 state doesn't know about them, so they stay in AWS outside state. Cleaning that up needs separately reviewed manual work. Don't treat a state restore as a rollback procedure.

## If you call a child module directly

The database, Brainstore deployment, API ECS and gateway ECS modules no longer create the roles in the table above. The root module passes them in, and you must do the same if you call one of these modules yourself.

New required inputs, each taking the matching output of `modules/iam`:

| Module | New required inputs |
| --- | --- |
| `database` | `monitoring_role_arn` |
| `brainstore-deployment` | `waiter_role_arn` |
| `api-ecs` | `task_execution_role_arn` |
| `gateway-ecs` | `task_execution_role_arn`, `task_role_arn` |

Removed inputs, which now belong to `modules/iam` or are gone:

| Module | Removed inputs |
| --- | --- |
| `database`, `brainstore-deployment`, `api-ecs`, `gateway-ecs` | `permissions_boundary_arn` |
| `api-ecs`, `gateway-ecs` | `custom_ca_bundle_kms_key_arn`, `brainstore_license_key_kms_key_arn` |
| `gateway-ecs` | `bedrock_assume_role_arns`, `diagnostics_transcript_log_group_name` |

Each `modules/iam` output waits only for the policies of its own role, so the consumer still waits for the permissions it needs.

**Note** - The `moved` blocks live in the root module's `moved_state.tf`, and Terraform applies them only to the root module's own addresses. If you call a child module directly, your state has the old addresses and the root blocks don't reach them. Add your own `moved` blocks that map each old address in the table above to wherever you create the role now, or the next apply destroys and recreates the roles.
