# Upgrade proof: applies the parent under mocks, then plans this working tree
# against the same state. scripts/check-upgrade-plan reads the plans these runs
# emit (`terraform test -json -verbose`) and fails on any action that isn't in
# tests/upgrade-allow-list.json, because assertions can't inspect planned
# actions. Run scripts/prepare-upgrade-fixture first to write the parent copy.
#
# The mocks prove the planned action set only. They can't prove apply ordering,
# IAM propagation or real provider behavior.

mock_provider "aws" {
  source = "./tests/mocks/aws"

  # Mock data sources return a new random string on every read unless pinned.
  # An unpinned partition rewrites every ARN built from it in each plan.
  mock_data "aws_partition" {
    defaults = { partition = "aws", dns_suffix = "amazonaws.com" }
  }
  mock_data "aws_eks_cluster" {
    defaults = { identity = [{ oidc = [{ issuer = "https://oidc.eks.us-east-1.amazonaws.com/id/EXAMPLED539D4633E53DE1B71EXAMPLE" }] }] }
  }
  mock_data "aws_secretsmanager_secret_versions" {
    defaults = {
      versions = [{ version_id = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee", version_stages = ["AWSCURRENT"] }]
    }
  }

  # An apply fills computed strings with random text. These resources feed
  # attributes that the provider validates as ARNs, or that the module parses.
  mock_resource "aws_appautoscaling_policy" {
    defaults = { arn = "arn:aws:autoscaling:us-east-1:123456789012:scalingPolicy:00000000-0000-0000-0000-000000000000:resource/ecs/service/mock:policyName/mock" }
  }
  mock_resource "aws_cloudwatch_event_rule" {
    defaults = { arn = "arn:aws:events:us-east-1:123456789012:rule/mock" }
  }
  mock_resource "aws_elasticache_cluster" {
    defaults = { cache_nodes = [{ id = "0001", address = "mock.cache.internal", port = 6379, availability_zone = "us-east-1a" }] }
  }
  mock_resource "aws_iam_instance_profile" {
    defaults = { arn = "arn:aws:iam::123456789012:instance-profile/mock" }
  }
  mock_resource "aws_iam_policy" {
    defaults = { arn = "arn:aws:iam::123456789012:policy/mock" }
  }
  mock_resource "aws_iam_role" {
    defaults = { arn = "arn:aws:iam::123456789012:role/mock" }
  }
  mock_resource "aws_kms_key" {
    defaults = { arn = "arn:aws:kms:us-east-1:123456789012:key/00000000-0000-0000-0000-000000000000" }
  }
  mock_resource "aws_lambda_function" {
    defaults = {
      arn        = "arn:aws:lambda:us-east-1:123456789012:function:mock"
      invoke_arn = "arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/arn:aws:lambda:us-east-1:123456789012:function:mock/invocations"
    }
  }
  mock_resource "aws_lambda_invocation" {
    defaults = { result = "{\"status\":\"complete\"}" }
  }
  mock_resource "aws_lambda_layer_version" {
    defaults = { arn = "arn:aws:lambda:us-east-1:123456789012:layer:mock:1" }
  }
  mock_resource "aws_launch_template" {
    defaults = { id = "lt-0123456789abcdef0", latest_version = 1 }
  }
  mock_resource "aws_lb" {
    defaults = { arn = "arn:aws:elasticloadbalancing:us-east-1:123456789012:loadbalancer/net/mock/1234567890123456" }
  }
  mock_resource "aws_lb_listener" {
    defaults = { arn = "arn:aws:elasticloadbalancing:us-east-1:123456789012:listener/app/mock/1234567890123456/1234567890123456" }
  }
  mock_resource "aws_lb_target_group" {
    defaults = { arn = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/mock/1234567890123456" }
  }
  mock_resource "aws_s3_bucket" {
    defaults = { arn = "arn:aws:s3:::mock-bucket" }
  }
}

mock_provider "random" {}

mock_provider "http" {
  source = "./tests/mocks/http"
}

variables {
  braintrust_org_name    = "test-org"
  primary_org_name       = "test-org"
  deployment_name        = "bt-test"
  brainstore_license_key = "test-license"
  enable_quarantine_vpc  = true
}

# Every IAM role, policy and instance profile, and every bucket, function and
# rule that a policy or permission names, gets its own ARN. With one shared
# mock ARN, a workload on the wrong role or a policy on the wrong bucket plans
# as a no-op, so the upgrade check couldn't catch it. check-upgrade-plan fails
# when two resources share an ARN, and --self-test proves the wrong wiring is
# rejected. The plan runs read these ARNs back from state, so only the apply
# runs use them.
#
# These overrides sit at the top of the file and apply to every run. A target
# that a run's configuration doesn't have, such as a v7 address in a parent run,
# is skipped. Terraform warns only about a target that no run has, and
# check-upgrade-plan treats that warning as an error. The parent and the release
# have different addresses for the roles that have moved, so both sets are here.
#
# An apply fills computed strings with random text, and the provider validates
# some of them as ARNs, so the mock_resource defaults above give each type a
# valid ARN too.

# Roles that moved into modules/iam in the parent. The parent runs address them
# there, and the release runs address them at their v7 addresses.
override_resource {
  target = module.iam.aws_iam_role.api_ecs_task_execution[0]
  values = { arn = "arn:aws:iam::123456789012:role/mock-api-ecs-task-execution" }
}
override_resource {
  target = module.iam.aws_iam_role.brainstore_deployment_waiter[0]
  values = { arn = "arn:aws:iam::123456789012:role/mock-brainstore-deployment-waiter" }
}
override_resource {
  target = module.iam.aws_iam_role.db_monitoring[0]
  values = { arn = "arn:aws:iam::123456789012:role/mock-database-db-monitoring" }
}
override_resource {
  target = module.iam.aws_iam_role.gateway_task[0]
  values = { arn = "arn:aws:iam::123456789012:role/mock-gateway-ecs-task" }
}
override_resource {
  target = module.iam.aws_iam_role.gateway_task_execution[0]
  values = { arn = "arn:aws:iam::123456789012:role/mock-gateway-ecs-task-execution" }
}
override_resource {
  target = module.api_ecs[0].aws_iam_role.task_execution
  values = { arn = "arn:aws:iam::123456789012:role/mock-api-ecs-task-execution" }
}
override_resource {
  target = module.brainstore_deployment[0].aws_iam_role.waiter
  values = { arn = "arn:aws:iam::123456789012:role/mock-brainstore-deployment-waiter" }
}
override_resource {
  target = module.database.aws_iam_role.db_monitoring
  values = { arn = "arn:aws:iam::123456789012:role/mock-database-db-monitoring" }
}
override_resource {
  target = module.gateway_ecs[0].aws_iam_role.task
  values = { arn = "arn:aws:iam::123456789012:role/mock-gateway-ecs-task" }
}
override_resource {
  target = module.gateway_ecs[0].aws_iam_role.task_execution
  values = { arn = "arn:aws:iam::123456789012:role/mock-gateway-ecs-task-execution" }
}

# Roles that are still in services-common, services and the brainstore module in
# the parent, and in the v7 release.
override_resource {
  target = module.services_common.aws_iam_role.api_handler_role
  values = { arn = "arn:aws:iam::123456789012:role/mock-services-common-api-handler" }
}
override_resource {
  target = module.services_common.aws_iam_role.brainstore_role
  values = { arn = "arn:aws:iam::123456789012:role/mock-services-common-brainstore" }
}
override_resource {
  target = module.services_common.aws_iam_role.quarantine_function_role[0]
  values = { arn = "arn:aws:iam::123456789012:role/mock-services-common-quarantine-function" }
}
override_resource {
  target = module.services_common.aws_iam_role.quarantine_invoke_role[0]
  values = { arn = "arn:aws:iam::123456789012:role/mock-services-common-quarantine-invoke" }
}
override_resource {
  target = module.services_common.aws_iam_policy.api_handler_policy
  values = { arn = "arn:aws:iam::123456789012:policy/mock-services-common-api-handler" }
}
override_resource {
  target = module.services_common.aws_iam_policy.api_handler_quarantine[0]
  values = { arn = "arn:aws:iam::123456789012:policy/mock-services-common-api-handler-quarantine" }
}
override_resource {
  target = module.brainstore[0].aws_iam_instance_profile.brainstore
  values = { arn = "arn:aws:iam::123456789012:instance-profile/mock-brainstore" }
}
override_resource {
  target = module.services[0].aws_iam_role.automation_cron_role
  values = { arn = "arn:aws:iam::123456789012:role/mock-services-automation-cron" }
}
override_resource {
  target = module.services[0].aws_iam_role.billing_cron
  values = { arn = "arn:aws:iam::123456789012:role/mock-services-billing-cron" }
}
override_resource {
  target = module.services[0].aws_iam_role.catchup_etl
  values = { arn = "arn:aws:iam::123456789012:role/mock-services-catchup-etl" }
}
override_resource {
  target = module.services[0].aws_iam_role.default_role
  values = { arn = "arn:aws:iam::123456789012:role/mock-services-default" }
}
override_resource {
  target = module.services[0].aws_iam_role.migrate_database
  values = { arn = "arn:aws:iam::123456789012:role/mock-services-migrate-database" }
}
override_resource {
  target = module.services[0].aws_iam_role.quarantine_warmup[0]
  values = { arn = "arn:aws:iam::123456789012:role/mock-services-quarantine-warmup" }
}
override_resource {
  target = module.services[0].aws_iam_policy.api_handler_lambda_policies
  values = { arn = "arn:aws:iam::123456789012:policy/mock-services-api-handler-lambda" }
}

# Buckets, functions and rules that a policy or permission names.
override_resource {
  target = module.storage.aws_s3_bucket.brainstore[0]
  values = { arn = "arn:aws:s3:::mock-storage-brainstore" }
}
override_resource {
  target = module.storage.aws_s3_bucket.code_bundle_bucket
  values = { arn = "arn:aws:s3:::mock-storage-code-bundle" }
}
override_resource {
  target = module.storage.aws_s3_bucket.lambda_responses_bucket
  values = { arn = "arn:aws:s3:::mock-storage-lambda-responses" }
}
override_resource {
  target = module.brainstore_deployment[0].aws_lambda_function.waiter
  values = {
    arn        = "arn:aws:lambda:us-east-1:123456789012:function:mock-brainstore-deployment-waiter"
    invoke_arn = "arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/arn:aws:lambda:us-east-1:123456789012:function:mock-brainstore-deployment-waiter/invocations"
  }
}
override_resource {
  target = module.services[0].aws_lambda_function.automation_cron
  values = {
    arn        = "arn:aws:lambda:us-east-1:123456789012:function:mock-services-automation-cron"
    invoke_arn = "arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/arn:aws:lambda:us-east-1:123456789012:function:mock-services-automation-cron/invocations"
  }
}
override_resource {
  target = module.services[0].aws_lambda_function.billing_cron
  values = {
    arn        = "arn:aws:lambda:us-east-1:123456789012:function:mock-services-billing-cron"
    invoke_arn = "arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/arn:aws:lambda:us-east-1:123456789012:function:mock-services-billing-cron/invocations"
  }
}
override_resource {
  target = module.services[0].aws_lambda_function.catchup_etl
  values = {
    arn        = "arn:aws:lambda:us-east-1:123456789012:function:mock-services-catchup-etl"
    invoke_arn = "arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/arn:aws:lambda:us-east-1:123456789012:function:mock-services-catchup-etl/invocations"
  }
}
override_resource {
  target = module.services[0].aws_lambda_function.migrate_database
  values = {
    arn        = "arn:aws:lambda:us-east-1:123456789012:function:mock-services-migrate-database"
    invoke_arn = "arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/arn:aws:lambda:us-east-1:123456789012:function:mock-services-migrate-database/invocations"
  }
}
override_resource {
  target = module.services[0].aws_lambda_function.quarantine_warmup[0]
  values = {
    arn        = "arn:aws:lambda:us-east-1:123456789012:function:mock-services-quarantine-warmup"
    invoke_arn = "arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/arn:aws:lambda:us-east-1:123456789012:function:mock-services-quarantine-warmup/invocations"
  }
}
override_resource {
  target = module.services[0].aws_cloudwatch_event_rule.automation_cron_schedule
  values = { arn = "arn:aws:events:us-east-1:123456789012:rule/mock-services-automation-cron" }
}
override_resource {
  target = module.services[0].aws_cloudwatch_event_rule.billing_cron_schedule
  values = { arn = "arn:aws:events:us-east-1:123456789012:rule/mock-services-billing-cron" }
}
override_resource {
  target = module.services[0].aws_cloudwatch_event_rule.catchup_etl_schedule
  values = { arn = "arn:aws:events:us-east-1:123456789012:rule/mock-services-catchup-etl" }
}

run "applies_parent_with_defaults" {
  command   = apply
  state_key = "defaults"

  module {
    source = "./tests/fixtures/.upgrade-parent"
  }
}

run "plans_working_tree_with_defaults" {
  command   = plan
  state_key = "defaults"
}

# The v7 release MIGRATION_V8.md says to upgrade from, pinned by base_ref in
# tests/upgrade-allow-list.release.json. The parent runs above only prove this
# PR against the one before it. These prove the whole stack against the release
# customers actually run, so a migration step lost along the way shows up here.
run "applies_release_with_defaults" {
  command   = apply
  state_key = "release"

  module {
    source = "./tests/fixtures/.upgrade-release"
  }
}

run "plans_working_tree_from_release" {
  command   = plan
  state_key = "release"
}

# Turns on every optional input that adds or changes a policy on a role that has
# moved into modules/iam, so the move is proven for those branches too. The
# apply and plan runs below must set identical variables, or the plan would
# show the difference instead of the move.
run "applies_parent_with_optional_iam_inputs" {
  command   = apply
  state_key = "optional_iam_inputs"

  module {
    source = "./tests/fixtures/.upgrade-parent"
  }
  variables {
    permissions_boundary_arn               = "arn:aws:iam::123456789012:policy/boundary"
    custom_tags                            = { team = "platform" }
    custom_ca_bundle_secret_arn            = "arn:aws:secretsmanager:us-east-1:123456789012:secret:ca-bundle-AbCdEf"
    custom_ca_bundle_kms_key_arn           = "arn:aws:kms:us-east-1:123456789012:key/11111111-1111-1111-1111-111111111111"
    existing_brainstore_license_key_secret = { arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:license-AbCdEf", kms_key_arn = "arn:aws:kms:us-east-1:123456789012:key/22222222-2222-2222-2222-222222222222" }
    internal_observability_api_key         = "test-observability-key"
    diagnostics_transcript_log_group_name  = "/braintrust-byoc/test/diagnostics"
    ai_gateway_enable_execute_command      = true
    ai_gateway_bedrock_assume_role_arns    = ["arn:aws:iam::210987654321:role/bedrock"]

    # Shared API role.
    service_additional_policy_arns             = ["arn:aws:iam::123456789012:policy/api-extra"]
    api_ecs_enable_execute_command             = true
    external_attachment_s3_bucket_arns         = ["arn:aws:s3:::attachments-a"]
    external_attachment_s3_bucket_kms_key_arns = ["arn:aws:kms:us-east-1:210987654321:key/33333333-3333-3333-3333-333333333333"]
    existing_attachment_s3_bucket_arn          = "arn:aws:s3:::attachments-b"
    existing_attachment_s3_bucket_kms_key_arn  = "arn:aws:kms:us-east-1:123456789012:key/44444444-4444-4444-4444-444444444444"
    s3_export_assume_role_arns                 = ["arn:aws:iam::210987654321:role/export"]

    # Brainstore role, with a caller-provided bucket.
    brainstore_additional_policy_arns         = ["arn:aws:iam::123456789012:policy/brainstore-extra"]
    brainstore_enable_export                  = true
    enable_brainstore_ec2_ssm                 = true
    create_brainstore_s3_bucket               = false
    existing_brainstore_s3_bucket_arn         = "arn:aws:s3:::existing-brainstore"
    existing_brainstore_s3_bucket_kms_key_arn = "arn:aws:kms:us-east-1:123456789012:key/55555555-5555-5555-5555-555555555555"
    postgres_connection_override              = { credentials_secret_arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:database-credentials-AbCdEf" }

    # Trust documents. The Brainstore trust is replaced outright, and the API
    # trust takes the EKS branches.
    existing_eks_cluster_arn                  = "arn:aws:eks:us-east-1:123456789012:cluster/test"
    eks_namespace                             = "braintrust"
    enable_eks_pod_identity                   = true
    enable_eks_irsa                           = true
    override_brainstore_iam_role_trust_policy = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Principal = { Service = "ec2.amazonaws.com" }, Action = "sts:AssumeRole" }] })
  }
}

run "plans_working_tree_with_optional_iam_inputs" {
  command   = plan
  state_key = "optional_iam_inputs"

  variables {
    permissions_boundary_arn               = "arn:aws:iam::123456789012:policy/boundary"
    custom_tags                            = { team = "platform" }
    custom_ca_bundle_secret_arn            = "arn:aws:secretsmanager:us-east-1:123456789012:secret:ca-bundle-AbCdEf"
    custom_ca_bundle_kms_key_arn           = "arn:aws:kms:us-east-1:123456789012:key/11111111-1111-1111-1111-111111111111"
    existing_brainstore_license_key_secret = { arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:license-AbCdEf", kms_key_arn = "arn:aws:kms:us-east-1:123456789012:key/22222222-2222-2222-2222-222222222222" }
    internal_observability_api_key         = "test-observability-key"
    diagnostics_transcript_log_group_name  = "/braintrust-byoc/test/diagnostics"
    ai_gateway_enable_execute_command      = true
    ai_gateway_bedrock_assume_role_arns    = ["arn:aws:iam::210987654321:role/bedrock"]

    # Shared API role.
    service_additional_policy_arns             = ["arn:aws:iam::123456789012:policy/api-extra"]
    api_ecs_enable_execute_command             = true
    external_attachment_s3_bucket_arns         = ["arn:aws:s3:::attachments-a"]
    external_attachment_s3_bucket_kms_key_arns = ["arn:aws:kms:us-east-1:210987654321:key/33333333-3333-3333-3333-333333333333"]
    existing_attachment_s3_bucket_arn          = "arn:aws:s3:::attachments-b"
    existing_attachment_s3_bucket_kms_key_arn  = "arn:aws:kms:us-east-1:123456789012:key/44444444-4444-4444-4444-444444444444"
    s3_export_assume_role_arns                 = ["arn:aws:iam::210987654321:role/export"]

    # Brainstore role, with a caller-provided bucket.
    brainstore_additional_policy_arns         = ["arn:aws:iam::123456789012:policy/brainstore-extra"]
    brainstore_enable_export                  = true
    enable_brainstore_ec2_ssm                 = true
    create_brainstore_s3_bucket               = false
    existing_brainstore_s3_bucket_arn         = "arn:aws:s3:::existing-brainstore"
    existing_brainstore_s3_bucket_kms_key_arn = "arn:aws:kms:us-east-1:123456789012:key/55555555-5555-5555-5555-555555555555"
    postgres_connection_override              = { credentials_secret_arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:database-credentials-AbCdEf" }

    # Trust documents. The Brainstore trust is replaced outright, and the API
    # trust takes the EKS branches.
    existing_eks_cluster_arn                  = "arn:aws:eks:us-east-1:123456789012:cluster/test"
    eks_namespace                             = "braintrust"
    enable_eks_pod_identity                   = true
    enable_eks_irsa                           = true
    override_brainstore_iam_role_trust_policy = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Principal = { Service = "ec2.amazonaws.com" }, Action = "sts:AssumeRole" }] })
  }
}

# External EKS has no API ECS, gateway, waiter or Lambda services, so only the
# shared roles, quarantine roles and database monitoring role exist. PR 5 changes
# its trust, so this proves the moves leave it alone first. It sets the same
# variables on the apply and the plan.
run "applies_parent_with_external_eks" {
  command   = apply
  state_key = "external_eks"

  module {
    source = "./tests/fixtures/.upgrade-parent"
  }

  variables {
    use_deployment_mode_external_eks = true

    # The shared API and Brainstore role branches that depend on external EKS.
    # Its Brainstore role takes the EKS trust branches, and an existing license
    # secret and a CA bundle are ignored there because Helm owns them. The API
    # Exec transcript policy needs API ECS, so it stays absent on both sides.
    existing_eks_cluster_arn               = "arn:aws:eks:us-east-1:123456789012:cluster/test"
    eks_namespace                          = "braintrust"
    enable_eks_pod_identity                = true
    enable_eks_irsa                        = true
    custom_ca_bundle_secret_arn            = "arn:aws:secretsmanager:us-east-1:123456789012:secret:ca-bundle-AbCdEf"
    custom_ca_bundle_kms_key_arn           = "arn:aws:kms:us-east-1:123456789012:key/11111111-1111-1111-1111-111111111111"
    existing_brainstore_license_key_secret = { arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:license-AbCdEf", kms_key_arn = "arn:aws:kms:us-east-1:123456789012:key/22222222-2222-2222-2222-222222222222" }
    brainstore_enable_export               = true
    s3_export_assume_role_arns             = ["arn:aws:iam::210987654321:role/export"]
    enable_brainstore_ec2_ssm              = true
    diagnostics_transcript_log_group_name  = "/braintrust-byoc/test/diagnostics"
    service_additional_policy_arns         = ["arn:aws:iam::123456789012:policy/api-extra"]
    brainstore_additional_policy_arns      = ["arn:aws:iam::123456789012:policy/brainstore-extra"]
    api_ecs_enable_execute_command         = true
  }
}

run "plans_working_tree_with_external_eks" {
  command   = plan
  state_key = "external_eks"

  variables {
    use_deployment_mode_external_eks = true

    # The shared API and Brainstore role branches that depend on external EKS.
    # Its Brainstore role takes the EKS trust branches, and an existing license
    # secret and a CA bundle are ignored there because Helm owns them. The API
    # Exec transcript policy needs API ECS, so it stays absent on both sides.
    existing_eks_cluster_arn               = "arn:aws:eks:us-east-1:123456789012:cluster/test"
    eks_namespace                          = "braintrust"
    enable_eks_pod_identity                = true
    enable_eks_irsa                        = true
    custom_ca_bundle_secret_arn            = "arn:aws:secretsmanager:us-east-1:123456789012:secret:ca-bundle-AbCdEf"
    custom_ca_bundle_kms_key_arn           = "arn:aws:kms:us-east-1:123456789012:key/11111111-1111-1111-1111-111111111111"
    existing_brainstore_license_key_secret = { arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:license-AbCdEf", kms_key_arn = "arn:aws:kms:us-east-1:123456789012:key/22222222-2222-2222-2222-222222222222" }
    brainstore_enable_export               = true
    s3_export_assume_role_arns             = ["arn:aws:iam::210987654321:role/export"]
    enable_brainstore_ec2_ssm              = true
    diagnostics_transcript_log_group_name  = "/braintrust-byoc/test/diagnostics"
    service_additional_policy_arns         = ["arn:aws:iam::123456789012:policy/api-extra"]
    brainstore_additional_policy_arns      = ["arn:aws:iam::123456789012:policy/brainstore-extra"]
    api_ecs_enable_execute_command         = true
  }
}
