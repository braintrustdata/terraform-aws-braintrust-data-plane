# External IAM mode. With create_iam = false this module creates nothing. It
# looks up each role and instance profile that the deployment needs, by name or
# by an existing_iam ARN, and checks that the security team created it. The
# outputs then read these lookups instead of created resources, so the root
# module wires its consumers the same way in both modes.
#
# The checks are postconditions on the lookups, not check blocks, so a failure
# stops the plan. Role names decide ARNs, so the module compares names and not
# ARNs when it looks for two roles that resolve to the same identity. That check
# is in locals.tf, because it also runs on a standalone call.

locals {
  # The roles that a deployment with these feature gates needs. Each gate matches
  # the count on the role's resource, with create_iam left out. The default and
  # AIProxy invoke roles aren't here: they are managed-only, so nothing looks
  # them up. Keep the keys in step with the key lists in variables.tf, which
  # reject a typo, and with the Role keys table in MIGRATION_V8.md.
  external_role_gates = {
    api_handler                  = true
    api_ecs_task_execution       = local.create_ecs_api
    brainstore                   = true
    quarantine_invoke            = var.enable_quarantine_vpc
    quarantine_function          = var.enable_quarantine_vpc
    gateway_task_execution       = local.create_ai_gateway
    gateway_task                 = local.create_ai_gateway
    db_monitoring                = true
    brainstore_deployment_waiter = local.create_brainstore_deployment_waiter
    automation_cron              = local.create_lambda_services
    billing_cron                 = local.create_lambda_services
    catchup_etl                  = local.create_lambda_services
    migrate_database             = local.create_lambda_services
    quarantine_pruner            = local.create_lambda_services && var.enable_quarantine_pruner
    quarantine_warmup            = local.create_lambda_services && var.enable_quarantine_vpc
    automation_cron_schedule     = local.create_lambda_services
    billing_cron_schedule        = local.create_lambda_services
    catchup_etl_schedule         = local.create_lambda_services
    quarantine_pruner_schedule   = local.create_lambda_services && var.enable_quarantine_pruner
  }

  external_role_keys = [for key, needed in local.external_role_gates : key if needed]

  # An existing_iam ARN takes precedence over a name. The lookup reads the role
  # that the ARN names and then checks that the ARN matches.
  existing_role_arns = {
    for key in local.external_role_keys :
    key => try(var.existing_iam["role.${key}"].arn, null)
  }

  external_role_names = {
    for key in local.external_role_keys :
    key => local.existing_role_arns[key] != null ? regex("[^/]+$", local.existing_role_arns[key]) : local.role_names[key]
  }

  existing_instance_profile_arn = try(var.existing_iam["instance_profile.brainstore"].arn, null)

  external_instance_profile_name = (
    local.existing_instance_profile_arn != null
    ? regex("[^/]+$", local.existing_instance_profile_arn)
    : try(var.existing_iam["instance_profile.brainstore"].name, local.instance_profile_names.brainstore)
  )

  # Role names, lowercased, of every role this call creates or looks up. A
  # standalone run has no existing_iam, so there the names come from the
  # defaults and overrides.
  lowercase_role_names = [for key in local.external_role_keys : lower(local.external_role_names[key])]
  duplicate_role_names = distinct([for name in local.lowercase_role_names : name if length([for other in local.lowercase_role_names : other if other == name]) > 1])

  external_role_arns = { for key, role in data.aws_iam_role.external : key => role.arn }
}

data "aws_iam_role" "external" {
  for_each = var.create_iam ? {} : { for key in local.external_role_keys : key => key }

  name = local.external_role_names[each.key]

  lifecycle {
    postcondition {
      condition     = startswith(self.arn, local.role_arn_prefix)
      error_message = "Role ${self.name} has the ARN ${self.arn}, which isn't a role in this partition and account. Expected an ARN that starts with ${local.role_arn_prefix}."
    }

    postcondition {
      condition     = local.existing_role_arns[each.key] != null ? self.arn == local.existing_role_arns[each.key] : self.path == coalesce(local.role_paths[each.key], "/")
      error_message = "Role ${self.name} has the ARN ${self.arn} and the path ${self.path}, which doesn't match the existing_iam ARN or the override_iam_names path for role.${each.key}. The default path is /."
    }

    # Two postconditions, so the message names the likely mistake. The first catches a
    # module-managed role, whose tag is braintrust. The second catches a missing tag,
    # which also covers a stack that skipped v7.3.0, and any other value.
    postcondition {
      condition     = try(self.tags["BraintrustIAMOwner"], null) != "braintrust"
      error_message = "Role ${self.name} carries BraintrustIAMOwner = braintrust, so a module-managed stack owns it, and setting create_iam = false would destroy it. External IAM mode is for new stacks only. It needs roles that your security team created with BraintrustIAMOwner = customer."
    }

    postcondition {
      condition     = contains(["braintrust", "customer"], try(self.tags["BraintrustIAMOwner"], ""))
      error_message = "Role ${self.name} is missing BraintrustIAMOwner = customer, found ${try(self.tags["BraintrustIAMOwner"], "no tag")}. External IAM mode needs roles that your security team created with that tag. modules/iam sets it when it creates them."
    }
  }
}

# The instance profile exports no tags, so the check runs on its role. The role
# must be the Brainstore role, and the Brainstore role lookup above checks the
# tag.
data "aws_iam_instance_profile" "external" {
  count = !var.create_iam && local.create_brainstore_ec2 ? 1 : 0

  name = local.external_instance_profile_name

  lifecycle {
    postcondition {
      condition     = startswith(self.arn, local.instance_profile_arn_prefix)
      error_message = "Instance profile ${self.name} has the ARN ${self.arn}, which isn't an instance profile in this partition and account."
    }

    postcondition {
      condition     = local.existing_instance_profile_arn != null ? self.arn == local.existing_instance_profile_arn : self.path == coalesce(local.instance_profile_paths.brainstore, "/")
      error_message = "Instance profile ${self.name} has the ARN ${self.arn} and the path ${self.path}, which doesn't match the existing_iam ARN or the override_iam_names path for instance_profile.brainstore. The default path is /."
    }

    postcondition {
      condition     = try(length(self.role_arn) > 0, false)
      error_message = "Instance profile ${self.name} has no role. Add the Brainstore role to it."
    }

    postcondition {
      condition     = self.role_arn == data.aws_iam_role.external["brainstore"].arn
      error_message = "Instance profile ${self.name} holds the role ${try(self.role_arn, "")}, but the Brainstore role is ${data.aws_iam_role.external["brainstore"].arn}. Brainstore's instance profile must hold the Brainstore role."
    }
  }
}
