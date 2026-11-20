# EventBridge Scheduler runs the AutomationCron, BillingCron, CatchupETL and
# QuarantinePruner functions. Each schedule sits beside its function in
# lambda-*.tf. They share this group, and the invocation roles that Scheduler
# assumes come from modules/iam.
#
# Each schedule sets retry_policy to 86400 seconds and 185 attempts. Those are the
# defaults of an EventBridge rule target, and setting them keeps the retry
# behavior the same and makes Scheduler's own defaults irrelevant.

locals {
  # Each schedule targets its function by name instead of by aws_lambda_function
  # attributes, so Terraform creates schedules without waiting for the database
  # migration or the Brainstore waiter. The invoke policies in modules/iam are
  # built from the same names. This ends at "function:", and callers add the
  # function name. The IAM module's lambda_function_arn_prefix ends at the
  # deployment name instead.
  lambda_function_arn_base = "arn:${data.aws_partition.current.partition}:lambda:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:function:"

  # The EventBridge scheduled-event envelope that handlers received from the
  # old rules. Scheduler fills in the <aws.scheduler.*> context attributes for
  # each invocation. This is a literal string and not jsonencode(), because
  # jsonencode() escapes the angle brackets as \u003c and \u003e, and Scheduler
  # only substitutes the literal placeholders. The schedule ARN comes from a
  # context attribute because the schedule can't reference itself.
  scheduled_event_input = chomp(<<-EOT
    {
      "version": "0",
      "id": "<aws.scheduler.execution-id>",
      "detail-type": "Scheduled Event",
      "source": "aws.events",
      "account": "${data.aws_caller_identity.current.account_id}",
      "time": "<aws.scheduler.scheduled-time>",
      "region": "${data.aws_region.current.region}",
      "resources": ["<aws.scheduler.schedule-arn>"],
      "detail": {}
    }
    EOT
  )
}

# modules/iam names this group in the trust policy of each invocation role, so
# keep the two names in step. Schedules can't carry tags, so the group does.
resource "aws_scheduler_schedule_group" "scheduled_jobs" {
  name = "${var.deployment_name}-scheduled-jobs"

  tags = local.common_tags
}
