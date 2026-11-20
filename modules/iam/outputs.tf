output "role_names" {
  description = "Role names by key, from the naming definitions and override_iam_names. Always populated, including when create_iam is false and for the managed-only default and AIProxy invoke roles. They carry no readiness edge. Wire consumers to the ARN outputs below instead, because a live role can keep an older physical name."
  value       = local.role_names
}

output "instance_profile_names" {
  description = "Instance profile names by key, from the naming definitions. Always populated, including when create_iam is false. They carry no readiness edge. Wire consumers to the ARN outputs below instead."
  value       = local.instance_profile_names
}

# With create_iam = false each ARN comes from the role's lookup in lookups.tf,
# and the depends_on lists below name resources that don't exist. The managed-only
# default and AIProxy invoke roles have no lookup, so their outputs stay null.
#
# Each ARN output waits only for its own role's policies. A consumer that reads
# the ARN then waits for those policies, without a dependency on this whole
# module. One shared edge would form a cycle: the database reads the
# db_monitoring ARN, and the waiter policy waits on Brainstore fleets, which
# read the database port.

output "db_monitoring_role_arn" {
  description = "ARN of the RDS enhanced monitoring role."
  value       = var.create_iam ? one(aws_iam_role.db_monitoring[*].arn) : lookup(local.external_role_arns, "db_monitoring", null)

  depends_on = [aws_iam_role_policy_attachment.db_monitoring]
}

output "brainstore_deployment_waiter_role_arn" {
  description = "ARN of the Brainstore deployment waiter role."
  value       = var.create_iam ? one(aws_iam_role.brainstore_deployment_waiter[*].arn) : lookup(local.external_role_arns, "brainstore_deployment_waiter", null)

  # The waiter function can't start a rollout without this policy.
  depends_on = [aws_iam_role_policy.brainstore_deployment_waiter]
}

output "api_ecs_task_execution_role_arn" {
  description = "ARN of the API ECS task execution role."
  value       = var.create_iam ? one(aws_iam_role.api_ecs_task_execution[*].arn) : lookup(local.external_role_arns, "api_ecs_task_execution", null)

  # A task definition revision that references secrets needs GetSecretValue first.
  depends_on = [
    aws_iam_role_policy_attachment.api_ecs_task_execution_default,
    aws_iam_role_policy.api_ecs_task_execution_secrets,
  ]
}

output "gateway_task_execution_role_arn" {
  description = "ARN of the gateway task execution role."
  value       = var.create_iam ? one(aws_iam_role.gateway_task_execution[*].arn) : lookup(local.external_role_arns, "gateway_task_execution", null)

  # A task definition revision that references secrets needs GetSecretValue first.
  depends_on = [
    aws_iam_role_policy_attachment.gateway_task_execution_default,
    aws_iam_role_policy.gateway_task_execution_custom_ca_bundle_secret,
    aws_iam_role_policy.gateway_task_execution_secrets,
    aws_iam_role_policy.gateway_task_execution_redis_secret,
  ]
}

output "gateway_task_role_arn" {
  description = "ARN of the gateway task role."
  value       = var.create_iam ? one(aws_iam_role.gateway_task[*].arn) : lookup(local.external_role_arns, "gateway_task", null)

  # The task definition reads this ARN, so the service waits for these
  # policies before it starts tasks that call AssumeRole or open Exec sessions.
  depends_on = [
    aws_iam_role_policy.gateway_task_customer_assume_role,
    aws_iam_role_policy.gateway_task_diagnostics_transcripts,
    aws_iam_role_policy.gateway_task_diagnostics_execute_command,
  ]
}

# The shared API and quarantine roles have no readiness edge. Their consumers
# don't wait for these policies.

output "api_handler_role_arn" {
  description = "ARN of the shared API role. API ECS tasks use it as their task role, and the APIHandler and AIProxy Lambdas use it as their execution role."
  value       = var.create_iam ? one(aws_iam_role.api_handler[*].arn) : lookup(local.external_role_arns, "api_handler", null)
}

output "quarantine_invoke_role_arn" {
  description = "ARN of the role the API handler assumes to invoke quarantined functions. Null when quarantine is off."
  value       = var.create_iam ? one(aws_iam_role.quarantine_invoke[*].arn) : lookup(local.external_role_arns, "quarantine_invoke", null)
}

output "quarantine_function_role_arn" {
  description = "ARN of the execution role of quarantined Lambda functions. Null when quarantine is off."
  value       = var.create_iam ? one(aws_iam_role.quarantine_function[*].arn) : lookup(local.external_role_arns, "quarantine_function", null)
}

output "brainstore_role_arn" {
  description = "ARN of the Brainstore role. It supports EC2, EKS Pod Identity and IRSA."
  value       = var.create_iam ? one(aws_iam_role.brainstore[*].arn) : lookup(local.external_role_arns, "brainstore", null)

  # Nothing in the root module reads this. The upgrade self-test wires it to the wrong workload, and later PRs will use it.
  # Instance profiles need these permissions before Brainstore starts.
  depends_on = [
    aws_iam_role_policy.brainstore_secrets_access,
    aws_iam_role_policy.brainstore_kms_policy,
    aws_iam_role_policy.brainstore_s3_access,
    aws_iam_role_policy.brainstore_ssm_parameter_access,
    aws_iam_role_policy.brainstore_cloudwatch_logs_access,
    aws_iam_role_policy.brainstore_cloudwatch_metrics,
  ]
}

output "brainstore_instance_profile_arn" {
  description = "ARN of the Brainstore instance profile. Null when Brainstore doesn't run on EC2."
  value       = var.create_iam ? one(aws_iam_instance_profile.brainstore[*].arn) : one(data.aws_iam_instance_profile.external[*].arn)

  # The launch templates read this ARN, so the fleets wait for the permissions
  # that Brainstore needs at boot. None of these policies read fleet values.
  depends_on = [
    aws_iam_role_policy.brainstore_secrets_access,
    aws_iam_role_policy.brainstore_kms_policy,
    aws_iam_role_policy.brainstore_s3_access,
    aws_iam_role_policy.brainstore_ssm_parameter_access,
    aws_iam_role_policy.brainstore_cloudwatch_logs_access,
    aws_iam_role_policy.brainstore_cloudwatch_metrics,
    aws_iam_role_policy.brainstore_redis_secret_access,
  ]
}

output "automation_cron_role_arn" {
  description = "ARN of the AutomationCron execution role."
  value       = var.create_iam ? one(aws_iam_role.automation_cron[*].arn) : lookup(local.external_role_arns, "automation_cron", null)

  # The function's VPC config needs the managed VPC policy before it is created.
  depends_on = [
    aws_iam_role_policy_attachment.automation_cron_vpc_access,
    aws_iam_role_policy.automation_cron_topic_map_report_read,
  ]
}

output "billing_cron_role_arn" {
  description = "ARN of the BillingCron execution role."
  value       = var.create_iam ? one(aws_iam_role.billing_cron[*].arn) : lookup(local.external_role_arns, "billing_cron", null)

  depends_on = [aws_iam_role_policy_attachment.billing_cron_vpc_access]
}

output "catchup_etl_role_arn" {
  description = "ARN of the CatchupETL execution role."
  value       = var.create_iam ? one(aws_iam_role.catchup_etl[*].arn) : lookup(local.external_role_arns, "catchup_etl", null)

  depends_on = [aws_iam_role_policy_attachment.catchup_etl_vpc_access]
}

output "migrate_database_role_arn" {
  description = "ARN of the database migration function's execution role."
  value       = var.create_iam ? one(aws_iam_role.migrate_database[*].arn) : lookup(local.external_role_arns, "migrate_database", null)

  depends_on = [aws_iam_role_policy_attachment.migrate_database_vpc_access]
}

output "quarantine_pruner_role_arn" {
  description = "ARN of the quarantine pruner's execution role. Null when the pruner is off."
  value       = var.create_iam ? one(aws_iam_role.quarantine_pruner[*].arn) : lookup(local.external_role_arns, "quarantine_pruner", null)

  # VPC ENI permissions must be attached before the function config is updated.
  depends_on = [aws_iam_role_policy_attachment.quarantine_pruner_vpc_access]
}

output "quarantine_warmup_role_arn" {
  description = "ARN of the quarantine warmup function's execution role. Null when quarantine is off."
  value       = var.create_iam ? one(aws_iam_role.quarantine_warmup[*].arn) : lookup(local.external_role_arns, "quarantine_warmup", null)

  # The function can't create quarantine functions without its policy.
  depends_on = [
    aws_iam_role_policy_attachment.quarantine_warmup_vpc_access,
    aws_iam_role_policy.quarantine_warmup,
  ]
}

output "ai_proxy_invoke_role_arn" {
  description = "ARN of the role the APIHandler Lambda assumes to invoke AIProxy. Null when enable_ecs_api removes the Lambda path."
  value       = one(aws_iam_role.ai_proxy_invoke[*].arn)

  # The exclusive reconciler already waits for the invoke policy, so this waits
  # for both.
  depends_on = [aws_iam_role_policies_exclusive.ai_proxy_invoke]
}

# Each schedule reads its invocation role through one of these outputs, so
# Scheduler can't validate a role before its invoke policy exists.

output "automation_cron_schedule_role_arn" {
  description = "ARN of the role that Scheduler assumes to invoke the AutomationCron function."
  value       = var.create_iam ? one(aws_iam_role.automation_cron_schedule[*].arn) : lookup(local.external_role_arns, "automation_cron_schedule", null)

  depends_on = [aws_iam_role_policy.automation_cron_schedule]
}

output "billing_cron_schedule_role_arn" {
  description = "ARN of the role that Scheduler assumes to invoke the BillingCron function."
  value       = var.create_iam ? one(aws_iam_role.billing_cron_schedule[*].arn) : lookup(local.external_role_arns, "billing_cron_schedule", null)

  depends_on = [aws_iam_role_policy.billing_cron_schedule]
}

output "catchup_etl_schedule_role_arn" {
  description = "ARN of the role that Scheduler assumes to invoke the CatchupETL function."
  value       = var.create_iam ? one(aws_iam_role.catchup_etl_schedule[*].arn) : lookup(local.external_role_arns, "catchup_etl_schedule", null)

  depends_on = [aws_iam_role_policy.catchup_etl_schedule]
}

output "quarantine_pruner_schedule_role_arn" {
  description = "ARN of the role that Scheduler assumes to invoke the quarantine pruner function. Null when the pruner is off."
  value       = var.create_iam ? one(aws_iam_role.quarantine_pruner_schedule[*].arn) : lookup(local.external_role_arns, "quarantine_pruner_schedule", null)

  depends_on = [aws_iam_role_policy.quarantine_pruner_schedule]
}
