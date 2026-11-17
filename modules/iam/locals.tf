data "aws_region" "current" {}
data "aws_partition" "current" {}
data "aws_caller_identity" "current" {}

locals {
  # The source modules disagree on whether a caller's BraintrustDeploymentName
  # tag can override the deployment name. Each role keeps its source module's
  # merge order, so moving it into this module doesn't change its tags.
  common_tags                      = merge({ BraintrustDeploymentName = var.deployment_name }, var.custom_tags)
  common_tags_deployment_name_wins = merge(var.custom_tags, { BraintrustDeploymentName = var.deployment_name })

  # Marks IAM this module owns. Merged last so callers can't override it. Each
  # variant keeps the merge order of the tags it extends.
  iam_tags                      = merge(local.common_tags, { BraintrustIAMOwner = "braintrust" })
  iam_tags_deployment_name_wins = merge(local.common_tags_deployment_name_wins, { BraintrustIAMOwner = "braintrust" })

  # Role names are defined once, here. A managed role takes its name from this
  # map, and role_names exposes it to anything that has to look a role up.
  role_names = {
    db_monitoring                = "${var.deployment_name}-db-monitoring"
    brainstore_deployment_waiter = "${var.deployment_name}-brainstore-deployment"
    api_ecs_task_execution       = "${var.deployment_name}-api-ecs-task-exec"
    gateway_task_execution       = "${var.deployment_name}-gateway-task-exec"
    gateway_task                 = "${var.deployment_name}-gateway-task"
  }

  # Derived from the raw root inputs the way the root module derives its
  # create_ecs_api and create_ai_gateway locals. The waiter gate matches the
  # count on the root's brainstore_deployment module.
  create_ecs_api                      = !var.use_deployment_mode_external_eks
  create_ai_gateway                   = var.create_ai_gateway && !var.use_deployment_mode_external_eks
  create_brainstore_deployment_waiter = !var.use_deployment_mode_external_eks

  # A caller-supplied resource wins over the one the root module created.
  kms_key_arn                        = var.kms_key_arn != null ? var.kms_key_arn : var.created_resources.kms_key_arn
  brainstore_license_key_secret_arn  = var.existing_brainstore_license_key_secret != null ? var.existing_brainstore_license_key_secret.arn : var.created_resources.brainstore_license_key_secret_arn
  brainstore_license_key_kms_key_arn = var.existing_brainstore_license_key_secret != null ? var.existing_brainstore_license_key_secret.kms_key_arn : null
}

data "aws_iam_policy_document" "ecs_task_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}
