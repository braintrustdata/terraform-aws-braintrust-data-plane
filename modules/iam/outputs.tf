output "role_names" {
  description = "Role names by key, from the naming definitions. Always populated, including when create_iam is false. They carry no readiness edge. Wire consumers to the ARN outputs below instead, because a live role can keep an older physical name."
  value       = local.role_names
}

# Each ARN output waits only for its own role's policies. A consumer that reads
# the ARN then waits for those policies, without a dependency on this whole
# module. One shared edge would form a cycle: the database reads the
# db_monitoring ARN, and the waiter policy waits on Brainstore fleets, which
# read the database port.

output "db_monitoring_role_arn" {
  description = "ARN of the RDS enhanced monitoring role."
  value       = one(aws_iam_role.db_monitoring[*].arn)

  depends_on = [aws_iam_role_policy_attachment.db_monitoring]
}

output "brainstore_deployment_waiter_role_arn" {
  description = "ARN of the Brainstore deployment waiter role."
  value       = one(aws_iam_role.brainstore_deployment_waiter[*].arn)

  # The waiter function can't start a rollout without this policy.
  depends_on = [aws_iam_role_policy.brainstore_deployment_waiter]
}

output "api_ecs_task_execution_role_arn" {
  description = "ARN of the API ECS task execution role."
  value       = one(aws_iam_role.api_ecs_task_execution[*].arn)

  # A task definition revision that references secrets needs GetSecretValue first.
  depends_on = [
    aws_iam_role_policy_attachment.api_ecs_task_execution_default,
    aws_iam_role_policy.api_ecs_task_execution_secrets,
  ]
}

output "gateway_task_execution_role_arn" {
  description = "ARN of the gateway task execution role."
  value       = one(aws_iam_role.gateway_task_execution[*].arn)

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
  value       = one(aws_iam_role.gateway_task[*].arn)

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
  value       = one(aws_iam_role.api_handler[*].arn)
}

output "quarantine_invoke_role_arn" {
  description = "ARN of the role the API handler assumes to invoke quarantined functions. Null when quarantine is off."
  value       = one(aws_iam_role.quarantine_invoke[*].arn)
}

output "quarantine_function_role_arn" {
  description = "ARN of the execution role of quarantined Lambda functions. Null when quarantine is off."
  value       = one(aws_iam_role.quarantine_function[*].arn)
}

output "brainstore_role_arn" {
  description = "ARN of the Brainstore role. It supports EC2, EKS Pod Identity and IRSA."
  value       = one(aws_iam_role.brainstore[*].arn)

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
  value       = one(aws_iam_instance_profile.brainstore[*].arn)

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
