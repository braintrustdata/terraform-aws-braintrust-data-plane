# Migrating to v8

Upgrade this Terraform module **one major version at a time**. See the [README](README.md#major-versions) for the general upgrade policy, and the [routine upgrade guide](https://docs.braintrust.dev/admin/self-hosting/upgrade/routine) for the standard process of bumping the module version and applying Terraform.

**Note** - This guide is still growing. These sections cover the starting version, the tooling requirement, the IAM move, the move to EventBridge Scheduler, external IAM mode and what the upgrade plan shows so far. Later v8 changes add their own sections.

## Start from v7.3.0 or later

Upgrade to v7.3.0 or a later v7 release, and apply it, before you move to v8. v7.3.0 is the oldest release we support upgrading from. Coming from an older v7 release puts the v7.3.0 changes into the same apply as v8, and we don't support that combination.

## Terraform 1.17 or newer

The root module and the examples require Terraform `>= 1.17.0`, and the module is validated on Terraform 1.17.2. We didn't look for a lower minimum. Child modules under `modules/` keep `>= 1.10.0`.

v7 allows Terraform `>= 1.10.0`, so you can move every pipeline that applies this module to Terraform 1.17 while you're still on v7. Do that first. Then the v8 apply is the only change in that pipeline.

If you run Atlantis or a similar tool, check two settings before you upgrade: the Terraform version the tool runs (for example `terraform_version` in `atlantis.yaml`) and the `required_version` in your own configuration. Either one can still be pinned below 1.17, and either one stops the plan.

### OpenTofu

OpenTofu is still supported. The root module and each example have a `versions.tofu` that requires OpenTofu `>= 1.13`, and OpenTofu reads that file instead of `versions.tf`. We validate the module and the examples with `tofu validate` on OpenTofu 1.13, and that is all. The upgrade test needs Terraform's `state_key`, which OpenTofu doesn't have, so nobody has run an OpenTofu upgrade against mocked or real state. Plan an OpenTofu upgrade on a copy of your state first.

## What changes on apply

The upgrade plan from v7.3.0 or later shows these kinds of change. Treat anything outside these lists as a reason to stop, and stop on any destroy or replacement that isn't listed.

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

### The ownership marker and the bucket policy moves

Every stack gets a new `terraform_data.iam_ownership_mode` resource. It has no AWS object, so creating it changes nothing in AWS. See [External IAM mode](#external-iam-mode-create_iam--false) for what it does.

The TLS-only bucket policies on the code bundle and Lambda responses buckets can now be turned off, so their resources gain an index. The `moved` blocks in `moved_state.tf` keep the policies in place. The plan shows them as moves with no change.

| Resource | Old address | New address |
| --- | --- | --- |
| Code bundle bucket policy | `module.storage.aws_s3_bucket_policy.code_bundle_bucket` | `module.storage.aws_s3_bucket_policy.code_bundle_bucket[0]` |
| Lambda responses bucket policy | `module.storage.aws_s3_bucket_policy.lambda_responses_bucket` | `module.storage.aws_s3_bucket_policy.lambda_responses_bucket[0]` |

A rollback to v7 doesn't recreate these policies. Terraform treats the single-instance address as the same resource as `[0]`, so a v7 plan has nothing to do for them. Rollback is still unsupported, because of the [IAM moves](#rollback).

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

## External IAM mode (`create_iam = false`)

By default the module creates every IAM role, policy and instance profile it needs, and `create_iam` is `true`. Set it to `false` when your security team creates that IAM separately. Your security team runs `modules/iam` on its own with `iam_owner = "customer"`, and this module looks the roles up by name and uses them. In this mode the module creates no IAM, writes no S3 bucket policy and declares no Lambda permission.

**This is for new stacks only.** Don't set `create_iam = false` in the same apply as the v8 upgrade, and don't set it on a stack that already ran this module with `create_iam = true`. Converting a stack isn't supported.

### What stops you from converting a stack

The module catches honest mistakes at plan time where the check is cheap. It documents deliberate bypasses and doesn't defend against them. Two checks work together.

1. **The ownership tag.** `modules/iam` tags every role, managed policy and instance profile it creates with `BraintrustIAMOwner`. A stack that created its own IAM uses `braintrust`, and your security team's roles use `customer`. With `create_iam = false` the plan fails unless every role the module looks up, and the role in the Brainstore instance profile, carries `customer`. A `braintrust` tag fails with a message that a module-managed stack owns the role. A missing tag fails too, which catches a stack that skipped v7.3.0.
2. **The ownership marker.** `terraform_data.iam_ownership_mode` stores the `create_iam` value that the stack first applied with and checks it on every later plan. Changing `create_iam` in either direction fails at plan time with `Resource postcondition failed` and the message `create_iam can't change on a stack that has already applied this module`. It fails regardless of name overrides, `existing_iam` references or legacy role names. It doesn't run on destroy plans, so a plain `terraform destroy` works on every stack.

On a stack that has applied v8, any plan that changes `create_iam` fails. On a stack that hasn't, typically a v7 stack on its first v8 apply, the tag check is the only guard. These are out of reach, and each leads to the same result on a stack without the marker: a `create_iam = false` plan that destroys every managed role, policy and instance profile.

- A manual state edit, including removing the marker.
- `-replace` or `taint` on the marker, which resets the stored value.
- Removing the whole configuration.
- A `-target` run that excludes the marker, and a stale saved plan.
- Tagging a module-managed role `customer`, or removing or changing its `braintrust` tag, on a stack without the marker.
- On a stack without the marker, name overrides, `existing_iam` references or legacy role names that point the lookups at roles your security team tagged `customer`, while the module-managed roles are still in state.

The result is a production outage, because ECS tasks, Brainstore and the Lambda functions lose their credentials, and it lasts until the IAM is rebuilt. Don't retag module-managed roles, and don't try to convert a stack with any of the above.

### What the module checks

Each lookup is a postcondition, so a failure stops the plan.

| Check | Fails when |
| --- | --- |
| Ownership tag | The role is tagged `braintrust`, has no `BraintrustIAMOwner` tag, or has any other value. |
| Account and partition | The role's ARN isn't in this account and partition. |
| Path | The path doesn't match the `override_iam_names` path, or `/` by default. An `existing_iam` ARN must match the lookup's ARN. |
| Distinct names | Two roles resolve to the same name, ignoring case. The Scheduler roles must differ from each other and from the Lambda execution roles. |
| Instance profile | The profile has no role, or its role isn't the Brainstore role. |

### Names

Every role and the Brainstore instance profile has a default name from `deployment_name`. The [role keys](#role-keys) table below lists them. Both maps default to `{}`, and both are rejected when `create_iam` is `true`.

```hcl
create_iam = false

override_iam_names = {
  "role.api_handler" = { name = "example-api", path = "/security/" }
}

existing_iam = {
  "role.gateway_task" = { arn = "arn:aws:iam::123456789012:role/security/example-gateway" }
}
```

`override_iam_names` changes only the fields you list. Pass the same map to `modules/iam` when your security team runs it, so the names it creates are the names this module looks up. `existing_iam` takes an exact reference when a lookup by name isn't right. Each reference is read back and checked like a name. The keys are `role.<key>`, using the keys in [Role keys](#role-keys), and `instance_profile.brainstore`. `role.default` and `role.ai_proxy_invoke` aren't keys, because a standalone run creates neither role.

### Role keys

| Key | Role | Needed when |
| --- | --- | --- |
| `api_handler` | `<deployment_name>-APIHandlerRole` | Always |
| `api_ecs_task_execution` | `<deployment_name>-api-ecs-task-exec` | Always, with ECS |
| `brainstore` | `<deployment_name>-brainstore-ec2-role` | Always. The instance profile `<deployment_name>-brainstore-instance-profile` is `instance_profile.brainstore`. |
| `quarantine_invoke`, `quarantine_function` | `<deployment_name>-QuarantineInvokeRole`, `<deployment_name>-QuarantineFunctionRole` | Quarantine on |
| `gateway_task_execution`, `gateway_task` | `<deployment_name>-gateway-task-exec`, `<deployment_name>-gateway-task` | `create_ai_gateway` |
| `db_monitoring` | `<deployment_name>-db-monitoring` | Always |
| `brainstore_deployment_waiter` | `<deployment_name>-brainstore-deployment` | Always |
| `automation_cron`, `billing_cron`, `catchup_etl`, `migrate_database` | `<deployment_name>-AutomationCronRole`, `-BillingCronRole`, `-CatchupETLRole`, `-MigrateDatabaseFunctionRole` | Always |
| `quarantine_pruner` | `<deployment_name>-QuarantinePrunerRole` | `enable_quarantine_pruner` |
| `quarantine_warmup` | `<deployment_name>-QuarantineWarmupRole` | Quarantine on |
| `automation_cron_schedule`, `billing_cron_schedule`, `catchup_etl_schedule` | `<deployment_name>-AutomationCronScheduleRole`, `-BillingCronScheduleRole`, `-CatchupETLScheduleRole` | Always |
| `quarantine_pruner_schedule` | `<deployment_name>-QuarantinePrunerScheduleRole` | `enable_quarantine_pruner` |

### What external mode rejects

The plan fails, with a message that names the input, for each of these:

- `enable_ecs_api = false`. Lambda ingress writes API Gateway and Function URL Lambda permissions, which are resource policies that your security team can't own yet.
- External EKS, Loop and MicroVM, remote support and the bastion, and module-managed Flow Logs.
- A module-managed main VPC or quarantine VPC. Supply `existing_vpc_id`, the existing subnets and, with quarantine, `existing_quarantine_vpc_id` and its three subnets.
- Quarantine PrivateLink, in public mode through `use_private_gateway_quarantine_proxy` and in private mode through `create_quarantine_api_access`.
- Inputs that put IAM content on the infrastructure side: `override_api_iam_role_trust_policy`, `override_brainstore_iam_role_trust_policy`, `permissions_boundary_arn`, `service_additional_policy_arns` and `brainstore_additional_policy_arns`. Your security team sets those on the roles it creates.
- Nonempty `s3_export_assume_role_arns` or `ai_gateway_bedrock_assume_role_arns`. They only set permission scopes, which this module doesn't write in external mode. Your security team passes them on its standalone call instead.
- `enable_eks_pod_identity = true`, `enable_eks_irsa = true`, and a non-null `existing_eks_cluster_arn` or `eks_namespace`. They only shape the role trust that this module doesn't render in external mode, so they would be silently ignored.

### Security's standalone call

Your security team creates the roles by running `modules/iam` on its own, with the source and version below. This is an example. Use the same values that you set on this module.

```hcl
module "braintrust_iam" {
  source = "github.com/braintrustdata/terraform-braintrust-data-plane//modules/iam?ref=<same_version_tag>"

  iam_owner  = "customer"
  create_iam = true

  deployment_name = "braintrust"
  region          = "us-east-1"
  account_id      = "123456789012"

  # The same sparse overrides that you pass to this module.
  # override_iam_names = {
  #   "role.api_handler" = { name = "example-api", path = "/security/" }
  # }

  # Feature gates: the values this stack will use.
  enable_ecs_api           = true
  create_ai_gateway        = true
  enable_quarantine_vpc    = true
  enable_quarantine_pruner = false

  # Caller-supplied resources: exact ARNs and IDs that exist before either team applies.
  existing_quarantine_vpc_id = "vpc-22222222222222222"
  # kms_key_arn                = "arn:aws:kms:us-east-1:123456789012:key/11111111-1111-1111-1111-111111111111"
  # custom_ca_bundle_secret_arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:braintrust-ca-bundle-AbCdEf"

  # Set both when this stack sets postgres_connection_override.
  # use_postgres_connection_override                    = true
  # postgres_connection_override_credentials_secret_arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:database-credentials-AbCdEf"

  # Standalone only. This stack rejects both lists in external mode.
  # s3_export_assume_role_arns          = []
  # ai_gateway_bedrock_assume_role_arns = []
}
```

The standalone call sets `iam_owner = "customer"`, so it creates neither the default role nor the AIProxy invoke role. It rejects `enable_ecs_api = false` and `create_iam = false`. It has no `created_resources`, so its policies scope module-created resources by name prefix, KMS alias and tag. `kms_key_arn = ""` means no caller key, as on this module.

Both calls must match on these inputs. A mismatch gives roles that don't fit the stack, or a lookup that can't find them.

| Input | Where it comes from here |
| --- | --- |
| `deployment_name`, `region`, `account_id` | The same deployment, and the account and region of this stack's provider. A check fails on a mismatch. |
| `override_iam_names` | This module's `override_iam_names`. |
| `enable_ecs_api`, `create_ai_gateway`, `enable_quarantine_vpc`, `enable_quarantine_pruner` | The same inputs on this module. |
| `enable_brainstore_ec2_ssm`, `brainstore_enable_export`, `api_ecs_enable_execute_command`, `ai_gateway_enable_execute_command`, `diagnostics_transcript_log_group_name` | The same inputs on this module. |
| `kms_key_arn`, `existing_quarantine_vpc_id` | The same inputs on this module. |
| `custom_ca_bundle_secret_arn` and `custom_ca_bundle_kms_key_arn`, `existing_brainstore_license_key_secret`, `existing_brainstore_s3_bucket_arn` and `existing_brainstore_s3_bucket_kms_key_arn` | The same inputs on this module. |
| `existing_attachment_s3_bucket_arn` and its key, `external_attachment_s3_bucket_arns` and `external_attachment_s3_bucket_kms_key_arns` | The same inputs on this module. |
| `use_postgres_connection_override`, `postgres_connection_override_credentials_secret_arn` | Whether this module's `postgres_connection_override` is set, and its `credentials_secret_arn`. |

Use the same module version on both sides. Pin both `source` lines to the same tag. When a shared input changes, your security team applies first, so this stack's lookups find the updated roles.

### Before you apply

Your security team provides these before the first apply, because this module doesn't create them:

- The roles and the Brainstore instance profile from the standalone call.
- The service-linked roles for ECS, Application Auto Scaling, RDS, ElastiCache, Elastic Load Balancing and Auto Scaling. `scripts/create-service-linked-roles.sh` creates only the Auto Scaling one. The module doesn't let a service create them through the deployer.
- For the principal that applies this stack: `iam:GetRole` and `iam:GetInstanceProfile` on the roles and the profile, which the lookups need even though nothing is created, and `iam:PassRole` scoped to each role with the right `iam:PassedToService`.
- The TLS-only policies on the three module-created buckets, applied after this stack creates them.

### Who owns what

Your security team owns the roles, their policies and the instance profile, and also the TLS-only policies on the three module-created buckets. This module no longer writes them when `create_iam = false`, and it doesn't check that they exist. Applying, enforcing and repairing them is your security team's job. The module keeps its buckets, log groups, functions, compute and KMS key. It creates the KMS key and doesn't change it afterward.

Your security team's policies scope the module's buckets, secrets, KMS key and Brainstore fleets by name prefix, the KMS alias `alias/braintrust/<deployment_name>` and tags, so it can create them before this module creates the resources. A bucket pattern such as `<deployment_name>-brainstore-*` also matches the buckets of a deployment whose name starts with `<deployment_name>-brainstore`. The module can't see other deployments, so pick deployment names that aren't prefixes of each other in one account, or use separate accounts.

That makes your security team the controller of two namespaces in the account: creation of `alias/braintrust/*` KMS aliases, because a role scoped to `alias/braintrust/<deployment_name>` reaches whatever key carries that alias, and the `<deployment_name>-*` bucket names, because a bucket pattern reaches any bucket in the account that matches it.

### The first minutes of a new stack

Alias-based KMS authorization can take a few minutes to apply after the alias exists. On a new external stack you can see `AccessDenied` on KMS or Secrets Manager from the first API deployment, the database migration, the quarantine warmup or Brainstore. Apply again. If the second plan shows no changes, a service that already failed won't retry by itself. Force a new ECS deployment for the API and gateway services, or start an instance refresh on the Brainstore Auto Scaling groups.

### Teardown

A plain `terraform destroy` works on every stack, because the marker's check doesn't run on destroy plans.

On an external stack, destroy this stack before your security team deletes the roles. The lookups and their checks run on destroy plans too, so deleting the roles first makes the destroy plan fail. If your security team already deleted them, it re-runs its apply to create them again, and then you destroy.

### Downgrading

A downgrade to a release before the marker, after the apply, removes the marker's protection. The tag check still fails an external-mode plan before it can destroy module-owned IAM, because a missing tag fails the check. Module-managed stacks keep the unsupported [rollback](#rollback) rules.

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

`modules/iam` itself has new required inputs, `region` and `account_id`, and new optional inputs, `iam_owner`, `override_iam_names`, `existing_iam`, `use_postgres_connection_override` and `postgres_connection_override_credentials_secret_arn`. The two required ones keep a standalone run's policy scopes from depending on whose credentials it uses, and a check fails if either differs from the provider's. The `storage` module has a new `manage_s3_bucket_policies` input, which defaults to `true`.

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
