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
