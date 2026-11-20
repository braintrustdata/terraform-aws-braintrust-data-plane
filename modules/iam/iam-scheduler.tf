# Invocation roles for the EventBridge Scheduler schedules in modules/services.
# Scheduler assumes one role per job and uses it to invoke that job's function,
# so the function needs no resource-based permission for Scheduler. These roles
# exist whenever the services module does. The pruner's exists only with the pruner.

locals {
  # The schedules sit in one group, which modules/services creates under this
  # name. The trust policy names it by ARN, so the roles don't wait for the group.
  schedule_group_arn = "arn:${data.aws_partition.current.partition}:scheduler:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:schedule-group/${var.deployment_name}-scheduled-jobs"

  # Scheduler may assume a role only for a schedule in this account's group. This
  # is the confused-deputy protection that the Scheduler documentation describes.
  scheduler_assume_role_policy = jsonencode({ # nosemgrep
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "scheduler.amazonaws.com"
        }
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
            "aws:SourceArn"     = local.schedule_group_arn
          }
        }
      }
    ]
  })
}

resource "aws_iam_role" "automation_cron_schedule" {
  count = var.create_iam && local.create_lambda_services ? 1 : 0

  name               = local.role_names.automation_cron_schedule
  assume_role_policy = local.scheduler_assume_role_policy

  permissions_boundary = var.permissions_boundary_arn

  tags = local.iam_tags
}

resource "aws_iam_role_policy" "automation_cron_schedule" {
  count = var.create_iam && local.create_lambda_services ? 1 : 0

  name = "${var.deployment_name}-AutomationCronScheduleRolePolicy"
  role = aws_iam_role.automation_cron_schedule[0].name

  policy = jsonencode({ # nosemgrep
    Version = "2012-10-17"
    Statement = [
      {
        Action   = "lambda:InvokeFunction"
        Effect   = "Allow"
        Resource = "${local.lambda_function_arn_prefix}-AutomationCron"
      }
    ]
  })
}

resource "aws_iam_role" "billing_cron_schedule" {
  count = var.create_iam && local.create_lambda_services ? 1 : 0

  name               = local.role_names.billing_cron_schedule
  assume_role_policy = local.scheduler_assume_role_policy

  permissions_boundary = var.permissions_boundary_arn

  tags = local.iam_tags
}

resource "aws_iam_role_policy" "billing_cron_schedule" {
  count = var.create_iam && local.create_lambda_services ? 1 : 0

  name = "${var.deployment_name}-BillingCronScheduleRolePolicy"
  role = aws_iam_role.billing_cron_schedule[0].name

  policy = jsonencode({ # nosemgrep
    Version = "2012-10-17"
    Statement = [
      {
        Action   = "lambda:InvokeFunction"
        Effect   = "Allow"
        Resource = "${local.lambda_function_arn_prefix}-BillingCron"
      }
    ]
  })
}

resource "aws_iam_role" "catchup_etl_schedule" {
  count = var.create_iam && local.create_lambda_services ? 1 : 0

  name               = local.role_names.catchup_etl_schedule
  assume_role_policy = local.scheduler_assume_role_policy

  permissions_boundary = var.permissions_boundary_arn

  tags = local.iam_tags
}

resource "aws_iam_role_policy" "catchup_etl_schedule" {
  count = var.create_iam && local.create_lambda_services ? 1 : 0

  name = "${var.deployment_name}-CatchupETLScheduleRolePolicy"
  role = aws_iam_role.catchup_etl_schedule[0].name

  policy = jsonencode({ # nosemgrep
    Version = "2012-10-17"
    Statement = [
      {
        Action   = "lambda:InvokeFunction"
        Effect   = "Allow"
        Resource = "${local.lambda_function_arn_prefix}-CatchupETL"
      }
    ]
  })
}

resource "aws_iam_role" "quarantine_pruner_schedule" {
  count = var.create_iam && local.create_lambda_services && var.enable_quarantine_pruner ? 1 : 0

  name               = local.role_names.quarantine_pruner_schedule
  assume_role_policy = local.scheduler_assume_role_policy

  permissions_boundary = var.permissions_boundary_arn

  tags = local.iam_tags
}

resource "aws_iam_role_policy" "quarantine_pruner_schedule" {
  count = var.create_iam && local.create_lambda_services && var.enable_quarantine_pruner ? 1 : 0

  name = "${var.deployment_name}-QuarantinePrunerScheduleRolePolicy"
  role = aws_iam_role.quarantine_pruner_schedule[0].name

  policy = jsonencode({ # nosemgrep
    Version = "2012-10-17"
    Statement = [
      {
        Action   = "lambda:InvokeFunction"
        Effect   = "Allow"
        Resource = "${local.lambda_function_arn_prefix}-QuarantinePrunerFunction"
      }
    ]
  })
}
