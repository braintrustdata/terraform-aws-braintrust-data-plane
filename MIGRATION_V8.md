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

This release moves these roles and the policies and attachments that belong to them. It also moves the Brainstore instance profile.

| Resource | Name | Old address | New address |
| --- | --- | --- | --- |
| RDS enhanced monitoring role | `<deployment_name>-db-monitoring` | `module.database.aws_iam_role.db_monitoring` | `module.iam.aws_iam_role.db_monitoring[0]` |
| Brainstore deployment waiter role | `<deployment_name>-brainstore-deployment` | `module.brainstore_deployment[0].aws_iam_role.waiter` | `module.iam.aws_iam_role.brainstore_deployment_waiter[0]` |
| API ECS task execution role | `<deployment_name>-api-ecs-task-exec` | `module.api_ecs[0].aws_iam_role.task_execution` | `module.iam.aws_iam_role.api_ecs_task_execution[0]` |
| Gateway task execution role | `<deployment_name>-gateway-task-exec` | `module.gateway_ecs[0].aws_iam_role.task_execution` | `module.iam.aws_iam_role.gateway_task_execution[0]` |
| Gateway task role | `<deployment_name>-gateway-task` | `module.gateway_ecs[0].aws_iam_role.task` | `module.iam.aws_iam_role.gateway_task[0]` |
| Shared API role | `<deployment_name>-APIHandlerRole` | `module.services_common.aws_iam_role.api_handler_role` | `module.iam.aws_iam_role.api_handler[0]` |
| Brainstore role | `<deployment_name>-brainstore-ec2-role` | `module.services_common.aws_iam_role.brainstore_role` | `module.iam.aws_iam_role.brainstore[0]` |
| Brainstore instance profile | `<deployment_name>-brainstore-instance-profile` | `module.brainstore[0].aws_iam_instance_profile.brainstore` | `module.iam.aws_iam_instance_profile.brainstore[0]` |
| Quarantine invoke role | `<deployment_name>-QuarantineInvokeRole` | `module.services_common.aws_iam_role.quarantine_invoke_role[0]` | `module.iam.aws_iam_role.quarantine_invoke[0]` |
| Quarantine function role | `<deployment_name>-QuarantineFunctionRole` | `module.services_common.aws_iam_role.quarantine_function_role[0]` | `module.iam.aws_iam_role.quarantine_function[0]` |

The shared API and Brainstore roles keep `ignore_changes = [name]`, so a stack with an older physical role name keeps it.

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
- The shared API role, which API ECS tasks and the APIHandler and AIProxy Lambdas use, loses its S3, KMS and export permissions until its policies are attached again.
- Running Brainstore instances lose access to their secrets, buckets and keys. Their instance profile and role are deleted, and the recreated role has a new unique ID, so the credentials they hold stop working. Plan on replacing the instances, because new ones can't start while the role or profile is missing.

A recreated role also breaks policies that you own. A policy that names one of these roles as a principal stores the role's unique ID when you save it, so it stops matching once the role has a new ID. That covers trust policies on roles in your accounts, such as the export roles you list in `s3_export_assume_role_arns`, and bucket and KMS key policies, including the ones on a bucket or key you supply yourself. The second apply doesn't touch them. You have to save each of them again.

We won't ship a v7.x patch that reverses the moves.

If an apply fails partway, fix the cause and apply v8 again. Don't pin v7. Before you upgrade, back up your state and confirm that the state backend has versioning turned on.

Restoring a v7 state backup doesn't get you back either. The v8 apply creates the Brainstore license secret, `${deployment_name}/brainstore/license-key`, and newer task definition and launch template versions. A restored v7 state doesn't know about them, so they stay in AWS outside state. Cleaning that up needs separately reviewed manual work. Don't treat a state restore as a rollback procedure.

## If you call a child module directly

The database, Brainstore deployment, API ECS, gateway ECS and Brainstore EC2 modules no longer create the resources in the table above, and `services-common` no longer creates any IAM. The root module passes each role in to the module that uses it, and you must do the same if you call one of these modules yourself. `services-common` uses no role, so it takes none.

New required inputs, each taking the matching output of `modules/iam`:

| Module | New required inputs |
| --- | --- |
| `database` | `monitoring_role_arn` |
| `brainstore-deployment` | `waiter_role_arn` |
| `api-ecs` | `task_execution_role_arn` |
| `gateway-ecs` | `task_execution_role_arn`, `task_role_arn` |
| `brainstore-ec2` | `instance_profile_arn`, replacing `brainstore_iam_role_name`. The module no longer creates the instance profile or the Redis secret policy. |

Removed inputs, which now belong to `modules/iam` or are gone:

| Module | What they were | Removed inputs |
| --- | --- | --- |
| `database`, `brainstore-deployment`, `api-ecs`, `gateway-ecs` | Permissions boundary | `permissions_boundary_arn` |
| `api-ecs`, `gateway-ecs` | KMS keys for secrets that a policy reads | `custom_ca_bundle_kms_key_arn`, `brainstore_license_key_kms_key_arn` |
| `gateway-ecs` | Gateway policy settings | `bedrock_assume_role_arns`, `diagnostics_transcript_log_group_name` |
| `services-common` | Permissions boundary | `permissions_boundary_arn` |
| `services-common` | Role trust settings | `eks_cluster_arn`, `eks_namespace`, `enable_eks_pod_identity`, `enable_eks_irsa`, `enable_ecs`, `override_api_iam_role_trust_policy`, `override_brainstore_iam_role_trust_policy` |
| `services-common` | Settings that add or change role policies | `api_ecs_enable_execute_command`, `enable_brainstore_ec2_ssm`, `diagnostics_transcript_log_group_name`, `service_additional_policy_arns`, `brainstore_additional_policy_arns`, `brainstore_enable_export`, `s3_export_assume_role_arns` |
| `services-common` | Bucket and database ARNs that policies name | `database_secret_arn`, `brainstore_s3_bucket_arn`, `brainstore_s3_bucket_kms_key_arn`, `code_bundle_s3_bucket_arn`, `lambda_responses_s3_bucket_arn`, `attachment_s3_bucket_arn`, `attachment_s3_bucket_kms_key_arn`, `external_attachment_s3_bucket_arns`, `external_attachment_s3_bucket_kms_key_arns` |
| `services-common` | Secret ARNs that policies name | `brainstore_license_key_secret_arn`, `brainstore_license_key_kms_key_arn`, `brainstore_custom_ca_bundle_secret_arn`, `brainstore_custom_ca_bundle_kms_key_arn`, `internal_observability_api_key_secret_arn` |

Each `modules/iam` output waits only for the policies of its own role, so the consumer still waits for the permissions it needs.

Removed outputs. `services-common` no longer creates these roles, so its outputs for them are gone. Read the matching `modules/iam` output instead:

| Module | Removed output | Replacement in `modules/iam` |
| --- | --- | --- |
| `services-common` | `api_handler_role_arn` | `api_handler_role_arn` |
| `services-common` | `api_handler_role_name` | `role_names["api_handler"]`. This is the default name. A live role can keep an older physical name, so take the name from the ARN output if you need the live one. |
| `services-common` | `brainstore_iam_role_arn` | `brainstore_role_arn` |
| `services-common` | `brainstore_iam_role_name` | `brainstore_instance_profile_arn`, which now carries the wait for the Brainstore policies. `role_names["brainstore"]` gives the default role name. A live role can keep an older physical name, so take the name from `brainstore_role_arn` if you need the live one. |
| `services-common` | `quarantine_invoke_role_arn` | `quarantine_invoke_role_arn` |
| `services-common` | `quarantine_function_role_arn` | `quarantine_function_role_arn` |

**Note** - The `moved` blocks live in the root module's `moved_state.tf`, and Terraform applies them only to the root module's own addresses. If you call a child module directly, your state has the old addresses and the root blocks don't reach them. Add your own `moved` blocks that map each old address to wherever you create the resource now, or the next apply destroys and recreates it. The root module's `moved_state.tf` is the complete list of addresses to move. The table above has one row per role, but each role also has policies and attachments that need their own blocks.
