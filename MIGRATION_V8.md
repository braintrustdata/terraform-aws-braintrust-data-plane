# Migrating to v8

Upgrade this Terraform module **one major version at a time**. See the [README](README.md#major-versions) for the general upgrade policy, and the [routine upgrade guide](https://docs.braintrust.dev/admin/self-hosting/upgrade/routine) for the standard process of bumping the module version and applying Terraform.

**Note** - This guide is still growing. These sections cover the starting version, the tooling requirement, the IAM move, the move to EventBridge Scheduler and what the upgrade plan shows so far. Later v8 changes add their own sections.

## Start from v7.3.0 or later

Upgrade to v7.3.0 or a later v7 release, and apply it, before you move to v8. v7.3.0 is the oldest release we support upgrading from. Coming from an older v7 release puts the v7.3.0 changes into the same apply as v8, and we don't support that combination.

## Terraform 1.17 or newer

The root module and the examples require Terraform `>= 1.17.0`, and the module is validated on Terraform 1.17.2. We didn't look for a lower minimum. Child modules under `modules/` keep `>= 1.10.0`.

v7 allows Terraform `>= 1.10.0`, so you can move every pipeline that applies this module to Terraform 1.17 while you're still on v7. Do that first. Then the v8 apply is the only change in that pipeline.

If you run Atlantis or a similar tool, check two settings before you upgrade: the Terraform version the tool runs (for example `terraform_version` in `atlantis.yaml`) and the `required_version` in your own configuration. Either one can still be pinned below 1.17, and either one stops the plan.

### OpenTofu

OpenTofu is still supported. The root module and each example have a `versions.tofu` that requires OpenTofu `>= 1.13`, and OpenTofu reads that file instead of `versions.tf`. We validate the module and the examples with `tofu validate` on OpenTofu 1.13, and that is all. The upgrade test needs Terraform's `state_key`, which OpenTofu doesn't have, so nobody has run an OpenTofu upgrade against mocked or real state. Plan an OpenTofu upgrade on a copy of your state first.

## What changes on apply

The upgrade plan from v7.3.0 or later shows three kinds of change. Treat anything outside these lists as a reason to stop, and stop on any destroy or replacement that isn't listed.

### IAM moves into `modules/iam`

v8 moves the module's IAM into a child module, `modules/iam`, so that a security team can later run it on its own. Managed stacks keep the same roles, names, trust documents, permissions and physical resources. The root module's `moved_state.tf` has a `moved` block for each resource, so these moves update state and nothing in AWS. The plan shows them as moves with no change. They don't republish a Lambda function, register a task definition revision or rerun the database migration.

This release moves these roles and the policies and attachments that belong to them. It also moves the Brainstore instance profile and the Lambda-path policy that only the Lambda API path uses.

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
| AutomationCron role | `<deployment_name>-AutomationCronRole` | `module.services[0].aws_iam_role.automation_cron_role` | `module.iam.aws_iam_role.automation_cron[0]` |
| BillingCron role | `<deployment_name>-BillingCronRole` | `module.services[0].aws_iam_role.billing_cron` | `module.iam.aws_iam_role.billing_cron[0]` |
| CatchupETL role | `<deployment_name>-CatchupETLRole` | `module.services[0].aws_iam_role.catchup_etl` | `module.iam.aws_iam_role.catchup_etl[0]` |
| Database migration role | `<deployment_name>-MigrateDatabaseFunctionRole` | `module.services[0].aws_iam_role.migrate_database` | `module.iam.aws_iam_role.migrate_database[0]` |
| Default role | `<deployment_name>-DefaultRole` | `module.services[0].aws_iam_role.default_role` | `module.iam.aws_iam_role.default[0]` |
| Quarantine pruner role | `<deployment_name>-QuarantinePrunerRole` | `module.services[0].aws_iam_role.quarantine_pruner_role[0]` | `module.iam.aws_iam_role.quarantine_pruner[0]` |
| Quarantine warmup role | `<deployment_name>-QuarantineWarmupRole` | `module.services[0].aws_iam_role.quarantine_warmup[0]` | `module.iam.aws_iam_role.quarantine_warmup[0]` |
| AIProxy invoke role | `<deployment_name>-AIProxyInvokeRole` | `module.services[0].aws_iam_role.ai_proxy_invoke_role[0]` | `module.iam.aws_iam_role.ai_proxy_invoke[0]` |
| APIHandler Lambda policy | `<deployment_name>-APIHandler-Lambdas` | `module.services[0].aws_iam_policy.api_handler_lambda_policies` | `module.iam.aws_iam_policy.api_handler_lambda_policies[0]` |

The AIProxy invoke role exists only when `enable_ecs_api` is `false`. On a v7 stack that keeps customer traffic on Lambda, it moves with the rest. On a stack that already runs on ECS there is nothing to move.

The shared API and Brainstore roles keep `ignore_changes = [name]`, so a stack with an older physical role name keeps it. The two Lambda attachments on the shared API role used to name the role with `basename` of its ARN. They now use the role's `name` attribute, which holds the same string.

The gateway Terraform files also split into `security-groups.tf` and `cloudwatch.tf` inside `modules/gateway-ecs`. That's a file move only, and no addresses change.

### Scheduled jobs move to EventBridge Scheduler

**This is a breaking change.** v8 replaces the four scheduled EventBridge rules with EventBridge Scheduler schedules, on every stack. There's no state move from a rule to a schedule, so the apply destroys the rules and creates the schedules. We did it this way so the module no longer writes a Lambda resource-based permission for each scheduled job. Scheduler invokes each function through an execution role instead, and that role is the whole authorization path.

Read the [Scheduler cutover runbook](#scheduler-cutover-runbook) before you apply. It has the preflight checks, the checks to run afterwards and what to watch.

Nothing about the jobs themselves changes. The same four Lambda functions run on the same rates:

| Job | Schedule name | Rate |
| --- | --- | --- |
| AutomationCron | `<deployment_name>-automation-cron-schedule` | `rate(10 minutes)` |
| BillingCron | `<deployment_name>-billing-cron-schedule` | `rate(5 minutes)` |
| CatchupETL | `<deployment_name>-catchup-etl-schedule` | `rate(10 minutes)` |
| QuarantinePruner | `<deployment_name>-quarantine-pruner-schedule` | `rate(1 hour)`, only when `enable_quarantine_pruner` is `true` |

The schedule names are the old rule names, and the schedules run in UTC with the flexible time window turned off. Each one retries a failed delivery for up to 24 hours and 185 attempts, which is what an EventBridge rule target does by default. Scheduler invokes the function asynchronously, as the rules did, and there's still no dead-letter queue.

The plan shows these changes from the Scheduler cutover:

- Creates:
  - the schedule group `module.services[0].aws_scheduler_schedule_group.scheduled_jobs`, named `<deployment_name>-scheduled-jobs`
  - the schedules, `module.services[0].aws_scheduler_schedule.automation_cron`, `billing_cron`, `catchup_etl` and, with the pruner on, `quarantine_pruner[0]`
  - the four invocation roles, `module.iam.aws_iam_role.automation_cron_schedule[0]`, `billing_cron_schedule[0]`, `catchup_etl_schedule[0]` and `quarantine_pruner_schedule[0]`, which is there only with the pruner on
  - each role's inline invoke policy, `module.iam.aws_iam_role_policy.<job>_schedule[0]`
- Destroys:
  - the rules `module.services[0].aws_cloudwatch_event_rule.automation_cron_schedule`, `billing_cron_schedule`, `catchup_etl_schedule` and `quarantine_pruner_schedule[0]`
  - their targets, `aws_cloudwatch_event_target.automation_cron_target`, `billing_cron_target`, `catchup_etl_target` and `quarantine_pruner_target[0]`
  - the four `aws_lambda_permission` resources for `events.amazonaws.com`, `allow_automation_cron_eventbridge`, `allow_billing_cron_eventbridge`, `allow_eventbridge` and `allow_quarantine_pruner_eventbridge[0]`

The four invocation roles are the only roles that v8 adds. Their default names are `<deployment_name>-AutomationCronScheduleRole`, `<deployment_name>-BillingCronScheduleRole`, `<deployment_name>-CatchupETLScheduleRole` and `<deployment_name>-QuarantinePrunerScheduleRole`. Each trusts `scheduler.amazonaws.com`, but only when the request comes from your account and from the `<deployment_name>-scheduled-jobs` group. Each allows `lambda:InvokeFunction` on its one function and nothing else.

#### What the jobs see differently

**The event payload.** An EventBridge rule sent each function a scheduled event. A schedule has no event unless you give it one, so the module rebuilds the same envelope as the schedule's input. Two values come from somewhere new:

| Field | v7 (rule) | v8 (schedule) |
| --- | --- | --- |
| `id` | A UUID for the event | The Scheduler execution ID, which is per delivery attempt and not a UUID |
| `resources` | The rule ARN | The schedule ARN |

`version`, `detail-type` (`Scheduled Event`), `source` (`aws.events`), `time`, `account`, `region` and `detail` (`{}`) keep their v7 shape. We checked the four handlers, and none of them reads `detail`, `source`, `time` or `resources`. They pass the event to their request logger and nothing more.

**The timing.** The module creates the schedules near the start of the apply, and the rules are destroyed in the same apply. The rate restarts when a schedule is created, so for each job one of these can happen:

- An extra run is possible. An event the rule already submitted can still be in Lambda's asynchronous queue when the schedule's first run lands, and the rule and the schedule can overlap for a moment.
- A gap is possible, of up to just under two intervals between runs. The last rule run could have been almost a full interval before the cutover, and the first schedule run could land almost a full interval after it.

It isn't established whether a new rate schedule runs once at creation or waits a full interval, so plan for either.

We traced all four jobs, and running one twice is safe:

| Job | Why a second run is safe |
| --- | --- |
| BillingCron | Usage counts drain from Redis atomically, and the pool-usage path holds a Postgres advisory lock |
| CatchupETL | Holds a Postgres advisory lock for the whole run, and a second run returns right away |
| AutomationCron | Locks each row with `FOR UPDATE NOWAIT` |
| QuarantinePruner | Treats a function that's already gone as deleted |

**The authorization.** A rule needed a Lambda permission that allowed `events.amazonaws.com` to call the function. A schedule doesn't. Scheduler assumes the job's invocation role and calls the function as that role. Two things follow:

- The principal that applies Terraform needs Scheduler and `iam:PassRole` permissions it didn't need before. The runbook lists them.
- A permissions boundary on the invocation roles can block the call. `permissions_boundary_arn` applies to the new roles like every other role the module creates.

**Managed-BYOC accounts need BYOC v2 first.** The deploy role for a managed-BYOC account gets its Scheduler permissions from BYOC v2 ([#407](https://github.com/braintrustdata/terraform-aws-braintrust-data-plane/pull/407)). That has to be live on the account before you apply v8. If it isn't, the apply can destroy some or all of the rules before the Scheduler calls fail. Any job whose rule is gone stops until a v8 apply succeeds.

### Braintrust service versions

The module pins Braintrust service versions, so if your v7 release pins an older version than this one, the upgrade also moves your services. Expect new task definition revisions for the API ECS services and the gateway, new Lambda versions, a Brainstore instance refresh and that version's database migrations. These aren't part of the IAM moves. To keep them out of the v8 apply, set the `*_version_override` inputs to the version you run now, as [MIGRATION_V7.md](MIGRATION_V7.md#v730-iam-ownership-tag) describes, and remove them in a later apply.

## Scheduler cutover runbook

This is the checklist for the [Scheduler change](#scheduled-jobs-move-to-eventbridge-scheduler). Do the first part before you apply, and the rest during and after.

### Before you apply

1. On managed-BYOC accounts, confirm BYOC v2 is live, so the deploy role has the Scheduler permissions in step 2.
1. On every stack, confirm the principal that applies Terraform has these permissions:
   - `scheduler:CreateScheduleGroup`, `scheduler:GetScheduleGroup`, `scheduler:DeleteScheduleGroup`, `scheduler:TagResource`, `scheduler:UntagResource` and `scheduler:ListTagsForResource`. The schedule group carries your custom tags, so removing one later needs `UntagResource`.
   - `scheduler:CreateSchedule`, `scheduler:GetSchedule`, `scheduler:UpdateSchedule` and `scheduler:DeleteSchedule`
   - `iam:PassRole` on the four `<deployment_name>-*ScheduleRole` roles, with `iam:PassedToService` set to `scheduler.amazonaws.com`
1. If you set `permissions_boundary_arn`, confirm the boundary allows `lambda:InvokeFunction` on the four cron functions. If it doesn't, the apply succeeds, but every delivery fails, Scheduler retries for 24 hours and then the events are dropped.
1. Confirm the stack is on v7.3.0 or later and a v7 `terraform plan` is clean. [Rollback](#rollback) covers the state backup.

You can check the permissions in step 2 with a simulation, which is read-only. Replace the placeholders with your account ID and deployment name, and `<principal_arn>` with the ARN of the role Terraform runs as. That's the role ARN (`arn:aws:iam::<account_id>:role/<name>`), not the assumed-role session ARN that `aws sts get-caller-identity` prints, which the simulator rejects.

```bash
aws iam simulate-principal-policy \
  --policy-source-arn <principal_arn> \
  --action-names scheduler:CreateScheduleGroup scheduler:GetScheduleGroup scheduler:DeleteScheduleGroup \
    scheduler:TagResource scheduler:UntagResource scheduler:ListTagsForResource scheduler:CreateSchedule scheduler:GetSchedule \
    scheduler:UpdateSchedule scheduler:DeleteSchedule \
  --resource-arns "*" \
  --query "EvaluationResults[?EvalDecision!='allowed'].[EvalActionName,EvalDecision]"

aws iam simulate-principal-policy \
  --policy-source-arn <principal_arn> \
  --action-names iam:PassRole \
  --resource-arns \
    arn:aws:iam::<account_id>:role/<deployment_name>-AutomationCronScheduleRole \
    arn:aws:iam::<account_id>:role/<deployment_name>-BillingCronScheduleRole \
    arn:aws:iam::<account_id>:role/<deployment_name>-CatchupETLScheduleRole \
    arn:aws:iam::<account_id>:role/<deployment_name>-QuarantinePrunerScheduleRole \
  --context-entries "ContextKeyName=iam:PassedToService,ContextKeyValues=scheduler.amazonaws.com,ContextKeyType=string" \
  --query "EvaluationResults[?EvalDecision!='allowed'].[EvalResourceName,EvalDecision]"
```

Each command prints nothing when everything is allowed. Leave out the pruner role if `enable_quarantine_pruner` is `false`. A simulation may not reflect every organization policy, such as a service control policy, so a clean result doesn't guarantee the apply will work.

### After you apply

1. Run `aws scheduler list-schedules --group-name <deployment_name>-scheduled-jobs`. It lists the schedules.
1. Run `aws events list-rules --name-prefix <deployment_name>-`. It no longer lists the four cron rules.
1. Confirm that each cron function really ran **after the apply finished**. A schedule can exist and still deliver nothing, for example when a boundary blocks the invoke. Runs from before the cutover don't count: the old rules triggered them, and one can still arrive from Lambda's queue. Note the time the apply finished, wait two intervals for each job (two hours for the pruner), then check that the function's Lambda `Invocations` metric is above zero **starting from that time**, or that its log group, such as `/braintrust/spiderman/spiderman-BillingCron` for a deployment named `spiderman`, has entries after it. Over the same window, Scheduler `InvocationAttemptCount` for the group should be above zero and `TargetErrorCount` should be zero.

For example, this prints the invocations of the BillingCron function since the apply finished. Set `APPLY_DONE` to that time in UTC.

```bash
APPLY_DONE=2026-11-20T18:00:00Z
aws cloudwatch get-metric-statistics --namespace AWS/Lambda --metric-name Invocations \
  --dimensions Name=FunctionName,Value=<deployment_name>-BillingCron \
  --start-time "$APPLY_DONE" --end-time "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --period 300 --statistics Sum
```

### What to watch

Scheduler publishes its metrics at account level and with a `ScheduleGroup` dimension, which is `<deployment_name>-scheduled-jobs`. There's no per-schedule dimension, so they can't tell the four jobs apart. When a Scheduler metric looks wrong, use the Lambda `Invocations` metric per function to find the failing job. CloudWatch delivers Scheduler's metrics on a best-effort basis, so a missing data point means little on its own. Lambda's own metrics show what actually ran.

| Signal | What to look for |
| --- | --- |
| Lambda `Invocations` per cron function | Resumes within two intervals after the apply finishes |
| Lambda `Errors`, `AsyncEventsDropped`, `AsyncEventAge` | No rise after the cutover |
| Scheduler `InvocationAttemptCount` | Above zero for the group, which shows Scheduler is delivering |
| Scheduler `TargetErrorCount`, `TargetErrorThrottledCount`, `InvocationThrottleCount`, `InvocationDroppedCount` | Zero |
| Downstream, such as the billing telemetry flush and Brainstore automation queue depth | Stay in their normal ranges |

A broken invocation role, or a boundary that blocks the call, has a recognizable signature. Lambda `Invocations` drops to zero while Scheduler `TargetErrorCount` rises. Scheduler keeps retrying each event for up to 24 hours and then drops it, and with no dead-letter queue the dropped events show up only in `InvocationDroppedCount`. If you fix the cause after several hours, the queued retries can arrive close together, which adds load on Postgres. The jobs are still safe to run twice. Scheduler counts a delivery as a success once Lambda accepts the event, so a failure inside the function is a separate Lambda signal.

### If the apply fails part way

Fix the cause and apply v8 again, as the [Rollback](#rollback) section says. A job whose rule is already destroyed and whose schedule isn't created yet stays stopped until a v8 apply succeeds. A failure in the Brainstore waiter partway through doesn't stop the schedules from being created, because they don't wait for it.

On a brand-new stack the schedules can exist before their functions do, because they don't wait for the database migration or the waiter. A delivery that arrives before the function exists fails. A function only exists after the migration finishes, so a run can't happen before the migration. Whether Scheduler retries a delivery to a function that doesn't exist yet isn't established.

## Rollback

**Rolling back to v7 after the v8 apply isn't supported.** v7 has no `moved` blocks for the `module.iam` addresses. A v7 plan on v8 state destroys the moved IAM at the new addresses and creates it again at the old ones. It also destroys the schedules, the schedule group and the four invocation roles, and creates the EventBridge rules, targets and Lambda permissions again.

The create runs while the role still exists, because the destroy of the new address hasn't finished. AWS rejects a second role with the same name, so the apply will likely fail partway with `EntityAlreadyExists` and need a second apply once the destroys complete. The recreated roles also have new unique IDs. Until the second apply succeeds, you can expect:

- RDS enhanced monitoring stops, because the monitoring role is missing or has no policy attachment.
- ECS tasks can't pull secrets, so new API and gateway tasks fail to start and replacements stall.
- The gateway task loses the credentials it uses to assume roles in your account, so Bedrock calls through the gateway fail.
- The Brainstore deployment waiter can't start a rollout.
- The shared API role, which API ECS tasks and the APIHandler and AIProxy Lambdas use, loses its S3, KMS and export permissions until its policies are attached again.
- Running Brainstore instances lose access to their secrets, buckets and keys. Their instance profile and role are deleted, and the recreated role has a new unique ID, so the credentials they hold stop working. Plan on replacing the instances, because new ones can't start while the role or profile is missing.
- The Lambda functions that run as a recreated role lose log and VPC access.

A recreated role also breaks policies that you own. A policy that names one of these roles as a principal stores the role's unique ID when you save it, so it stops matching once the role has a new ID. That covers trust policies on roles in your accounts, such as the export roles you list in `s3_export_assume_role_arns`, and bucket and KMS key policies, including the ones on a bucket or key you supply yourself. The second apply doesn't touch them. You have to save each of them again.

We won't ship a v7.x patch that reverses the moves.

If an apply fails partway, fix the cause and apply v8 again. Don't pin v7. Before you upgrade, back up your state and confirm that the state backend has versioning turned on. The [Scheduler cutover runbook](#scheduler-cutover-runbook) covers what a partial apply means for the scheduled jobs.

Restoring a v7 state backup doesn't get you back either. The v8 apply creates the Brainstore license secret, `${deployment_name}/brainstore/license-key`, and newer task definition and launch template versions. A restored v7 state doesn't know about them, so they stay in AWS outside state. It also leaves the schedules, the schedule group and the invocation roles in AWS but outside state. They keep firing next to the recreated rules, so every scheduled job runs twice. Cleaning that up needs separately reviewed manual work. Don't treat a state restore as a rollback procedure.

## If you call a child module directly

The database, Brainstore deployment, API ECS, gateway ECS, services and Brainstore EC2 modules no longer create the resources in the table above, and `services-common` no longer creates any IAM. The root module passes each role in to the module that uses it, and you must do the same if you call one of these modules yourself. `services-common` uses no role, so it takes none.

New required inputs, each taking the matching output of `modules/iam`:

| Module | New required inputs |
| --- | --- |
| `database` | `monitoring_role_arn` |
| `brainstore-deployment` | `waiter_role_arn` |
| `api-ecs` | `task_execution_role_arn` |
| `gateway-ecs` | `task_execution_role_arn`, `task_role_arn` |
| `services` | `automation_cron_role_arn`, `billing_cron_role_arn`, `catchup_etl_role_arn`, `migrate_database_role_arn`, `automation_cron_schedule_role_arn`, `billing_cron_schedule_role_arn` and `catchup_etl_schedule_role_arn`. Also `quarantine_pruner_role_arn`, `quarantine_pruner_schedule_role_arn`, `quarantine_warmup_role_arn` and `ai_proxy_invoke_role_arn`, which default to `null`. Set each when its feature is on. The module refuses to plan without `quarantine_pruner_schedule_role_arn` when `enable_quarantine_pruner` is `true`, and the APIHandler Lambda refuses to plan without `ai_proxy_invoke_role_arn` when `enable_ecs_api` is `false`. |
| `brainstore-ec2` | `instance_profile_arn`, replacing `brainstore_iam_role_name`. The module no longer creates the instance profile or the Redis secret policy. |

Removed inputs, which now belong to `modules/iam` or are gone:

| Module | What they were | Removed inputs |
| --- | --- | --- |
| `database`, `brainstore-deployment`, `api-ecs`, `gateway-ecs` | Permissions boundary | `permissions_boundary_arn` |
| `api-ecs`, `gateway-ecs` | KMS keys for secrets that a policy reads | `custom_ca_bundle_kms_key_arn`, `brainstore_license_key_kms_key_arn` |
| `gateway-ecs` | Gateway policy settings | `bedrock_assume_role_arns`, `diagnostics_transcript_log_group_name` |
| `services` | Permissions boundary | `permissions_boundary_arn` |
| `services-common` | Permissions boundary | `permissions_boundary_arn` |
| `services-common` | Role trust settings | `eks_cluster_arn`, `eks_namespace`, `enable_eks_pod_identity`, `enable_eks_irsa`, `enable_ecs`, `override_api_iam_role_trust_policy`, `override_brainstore_iam_role_trust_policy` |
| `services-common` | Settings that add or change role policies | `api_ecs_enable_execute_command`, `enable_brainstore_ec2_ssm`, `diagnostics_transcript_log_group_name`, `service_additional_policy_arns`, `brainstore_additional_policy_arns`, `brainstore_enable_export`, `s3_export_assume_role_arns` |
| `services-common` | Bucket and database ARNs that policies name | `database_secret_arn`, `brainstore_s3_bucket_arn`, `brainstore_s3_bucket_kms_key_arn`, `code_bundle_s3_bucket_arn`, `lambda_responses_s3_bucket_arn`, `attachment_s3_bucket_arn`, `attachment_s3_bucket_kms_key_arn`, `external_attachment_s3_bucket_arns`, `external_attachment_s3_bucket_kms_key_arns` |
| `services-common` | Secret ARNs that policies name | `brainstore_license_key_secret_arn`, `brainstore_license_key_kms_key_arn`, `brainstore_custom_ca_bundle_secret_arn`, `brainstore_custom_ca_bundle_kms_key_arn`, `internal_observability_api_key_secret_arn` |

Each `modules/iam` output waits only for the policies of its own role, so the consumer still waits for the permissions it needs.

`modules/iam` also exposes `role_names` and `instance_profile_names`, maps from each role or profile key to its default name. They're always filled in, and they carry no wait for any policy, so read the ARN outputs when a resource has to wait for a role.

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
