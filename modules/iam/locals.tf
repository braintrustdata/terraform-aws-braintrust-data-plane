data "aws_partition" "current" {}

# Policy scopes use the region and account ID that the caller passes in. These
# checks fail a run whose credentials point somewhere else, in both owner modes.
data "aws_region" "current" {
  lifecycle {
    postcondition {
      condition     = self.region == var.region
      error_message = "region is ${var.region}, but this module's AWS provider runs in ${self.region}. Use a provider for the region that the deployment runs in."
    }
  }
}

data "aws_caller_identity" "current" {
  lifecycle {
    # IAM role names are unique regardless of case, so two keys whose names differ
    # only in case collide. This runs on every call, because a standalone run
    # creates the roles and the root's external call looks them up. It sits here
    # because this data source needs no resource of its own to hang a check on.
    precondition {
      condition     = length(local.duplicate_role_names) == 0
      error_message = "Each role needs its own name, and IAM names are unique regardless of case. These names are used more than once: ${join(", ", local.duplicate_role_names)}. Check override_iam_names and existing_iam."
    }

    postcondition {
      condition     = self.account_id == var.account_id
      error_message = "account_id is ${var.account_id}, but this module's AWS provider runs in account ${self.account_id}. Use credentials for the account that the deployment runs in."
    }
  }
}

locals {
  partition = data.aws_partition.current.partition

  # Which call this is: the root's managed call, or security's standalone run. The
  # root never passes iam_owner, so it keeps the default and is the managed call.
  is_managed_call    = var.iam_owner == "braintrust"
  is_standalone_call = var.iam_owner == "customer"

  # ARN prefixes for the external lookups and the standalone scopes.
  role_arn_prefix             = "arn:${local.partition}:iam::${var.account_id}:role/"
  instance_profile_arn_prefix = "arn:${local.partition}:iam::${var.account_id}:instance-profile/"

  # The source modules disagree on whether a caller's BraintrustDeploymentName
  # tag can override the deployment name. Each role keeps its source module's
  # merge order, so moving it into this module doesn't change its tags.
  common_tags                      = merge({ BraintrustDeploymentName = var.deployment_name }, var.custom_tags)
  common_tags_deployment_name_wins = merge(var.custom_tags, { BraintrustDeploymentName = var.deployment_name })

  # Marks who owns the IAM this module creates: "braintrust" on the root's
  # managed call, "customer" when security runs the module on its own. Merged
  # last so callers can't override it. Each variant keeps the merge order of the
  # tags it extends.
  iam_tags                      = merge(local.common_tags, { BraintrustIAMOwner = var.iam_owner })
  iam_tags_deployment_name_wins = merge(local.common_tags_deployment_name_wins, { BraintrustIAMOwner = var.iam_owner })

  # Default role names are defined once, here. override_iam_names changes only
  # the entries it lists, and role_names below is what a role takes its name
  # from and what role_names exposes to anything that has to look a role up.
  default_role_names = {
    db_monitoring                = "${var.deployment_name}-db-monitoring"
    brainstore_deployment_waiter = "${var.deployment_name}-brainstore-deployment"
    api_ecs_task_execution       = "${var.deployment_name}-api-ecs-task-exec"
    gateway_task_execution       = "${var.deployment_name}-gateway-task-exec"
    gateway_task                 = "${var.deployment_name}-gateway-task"
    api_handler                  = "${var.deployment_name}-APIHandlerRole"
    brainstore                   = "${var.deployment_name}-brainstore-ec2-role"
    quarantine_invoke            = "${var.deployment_name}-QuarantineInvokeRole"
    quarantine_function          = "${var.deployment_name}-QuarantineFunctionRole"
    automation_cron              = "${var.deployment_name}-AutomationCronRole"
    billing_cron                 = "${var.deployment_name}-BillingCronRole"
    catchup_etl                  = "${var.deployment_name}-CatchupETLRole"
    migrate_database             = "${var.deployment_name}-MigrateDatabaseFunctionRole"
    quarantine_pruner            = "${var.deployment_name}-QuarantinePrunerRole"
    quarantine_warmup            = "${var.deployment_name}-QuarantineWarmupRole"
    default                      = "${var.deployment_name}-DefaultRole"
    ai_proxy_invoke              = "${var.deployment_name}-AIProxyInvokeRole"
    automation_cron_schedule     = "${var.deployment_name}-AutomationCronScheduleRole"
    billing_cron_schedule        = "${var.deployment_name}-BillingCronScheduleRole"
    catchup_etl_schedule         = "${var.deployment_name}-CatchupETLScheduleRole"
    quarantine_pruner_schedule   = "${var.deployment_name}-QuarantinePrunerScheduleRole"
  }

  role_names = {
    for key, default_name in local.default_role_names :
    key => try(var.override_iam_names["role.${key}"].name, default_name)
  }

  # Null leaves path unset, so the provider keeps its default, "/", and an
  # existing role shows no diff. Only an override sets it.
  role_paths = {
    for key in keys(local.default_role_names) :
    key => try(var.override_iam_names["role.${key}"].path, null)
  }

  # The same, for instance profiles.
  instance_profile_names = {
    brainstore = try(var.override_iam_names["instance_profile.brainstore"].name, "${var.deployment_name}-brainstore-instance-profile")
  }

  instance_profile_paths = {
    brainstore = try(var.override_iam_names["instance_profile.brainstore"].path, null)
  }

  # Built from the function names in modules/services, so the Scheduler invoke
  # policies don't wait for the functions, which wait for their execution roles.
  # This ends at the deployment name, and callers add "-<Function>". The services
  # module's lambda_function_arn_base ends at "function:" instead.
  #
  # This prefix, the managed policies, the Scheduler trust and the diagnostics
  # ARNs keep the data.aws_region and data.aws_caller_identity references they
  # had before this module took region and account_id, so a managed plan doesn't
  # change. The checks on those two data sources make them equal to var.region
  # and var.account_id. Everything added for a standalone run uses the variables.
  lambda_function_arn_prefix = "arn:${local.partition}:lambda:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:function:${var.deployment_name}"

  # Derived from the raw root inputs the way the root module derives its
  # create_ecs_api, enable_ecs_api, create_ai_gateway and create_brainstore_ec2
  # locals. The waiter and Lambda gates match the count on the root's
  # brainstore_deployment and services modules.
  create_ecs_api                      = !var.use_deployment_mode_external_eks
  enable_ecs_api                      = local.create_ecs_api && var.enable_ecs_api
  create_ai_gateway                   = var.create_ai_gateway && !var.use_deployment_mode_external_eks
  create_brainstore_ec2               = !var.use_deployment_mode_external_eks
  create_brainstore_deployment_waiter = !var.use_deployment_mode_external_eks
  create_lambda_services              = !var.use_deployment_mode_external_eks

  # A caller-supplied resource wins over the one the root module created.
  # The root's kms_key_arn defaults to "" and the root converts that to null
  # before calling this module. Security may copy the "" onto a standalone call,
  # so an empty string means no caller key here too.
  caller_kms_key_arn                 = var.kms_key_arn == "" ? null : var.kms_key_arn
  kms_key_arn                        = local.caller_kms_key_arn != null ? local.caller_kms_key_arn : var.created_resources.kms_key_arn
  brainstore_license_key_secret_arn  = var.existing_brainstore_license_key_secret != null ? var.existing_brainstore_license_key_secret.arn : var.created_resources.brainstore_license_key_secret_arn
  brainstore_license_key_kms_key_arn = var.existing_brainstore_license_key_secret != null ? var.existing_brainstore_license_key_secret.kms_key_arn : null
  brainstore_s3_bucket_arn           = var.existing_brainstore_s3_bucket_arn != null ? var.existing_brainstore_s3_bucket_arn : var.created_resources.brainstore_s3_bucket_arn
  quarantine_vpc_id                  = var.existing_quarantine_vpc_id != null ? var.existing_quarantine_vpc_id : var.created_resources.quarantine_vpc_id

  # OIDC issuer URL for the EKS cluster, for the IRSA trust on the shared API and Brainstore roles.
  eks_oidc_issuer_url = var.eks_cluster_arn != null && var.enable_eks_irsa ? data.aws_eks_cluster.cluster[0].identity[0].oidc[0].issuer : null
}

data "aws_eks_cluster" "cluster" {
  count = var.eks_cluster_arn != null && var.enable_eks_irsa ? 1 : 0
  name  = split("/", var.eks_cluster_arn)[1]
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
