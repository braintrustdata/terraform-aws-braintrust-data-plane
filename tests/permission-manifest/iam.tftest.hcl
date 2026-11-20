# Generation profiles for modules/iam. scripts/check-permission-manifest runs
# these through `terraform test -test-directory=tests/permission-manifest`, and
# the ordinary `terraform test` never reads this directory. Every run applies the
# module under mock providers, so the script can read the policy documents from
# the test state. See scripts/check-permission-manifest for the substitutions.
#
# The profiles come in two kinds. The managed runs are the root module's call:
# iam_owner is left at its default, and the root passes the ARNs of the resources
# it created in created_resources. The standalone runs are what a security team
# applies on its own with iam_owner = "customer". They have no created_resources,
# so the policies scope resources by prefix, alias and tag instead of exact ARNs.
#
# Each role gets an override_resource with the id and ARN `manifest-<role key>`,
# which the script turns into `${role:<role key>}`. In modules/iam the role key is
# the resource name. Other modules write it as <module>.<resource name>, with a dot.
# Other resources use `manifest-<module>-<resource name>`, with a hyphen, and the
# script turns those into bindings.
#
# The variables of each run are spelled out in full, not shared through a
# file-level variables block. A run sets whole objects such as created_resources,
# which a run-level value replaces rather than merges, and a reader can see what
# each profile switches on without tracing an inheritance chain.

mock_provider "aws" {
  source = "./tests/mocks/aws"

  mock_data "aws_partition" {
    defaults = { partition = "aws-manifest", dns_suffix = "amazonaws.com" }
  }
  mock_data "aws_eks_cluster" {
    defaults = { identity = [{ oidc = [{ issuer = "https://oidc.eks.us-east-1.amazonaws.com/id/EXAMPLED539D4633E53DE1B71EXAMPLE" }] }] }
  }

  # Apply mode materializes concrete values, and the provider validates many of
  # them as ARNs. These defaults only keep that validation happy. They give every
  # resource of a type the same ARN, so each role and policy below gets its own
  # through override_resource.
  mock_resource "aws_iam_role" {
    defaults = { arn = "arn:aws-manifest:iam::123456789012:role/manifest-unoverridden" }
  }
  mock_resource "aws_iam_policy" {
    defaults = { arn = "arn:aws-manifest:iam::123456789012:policy/manifest-unoverridden" }
  }
  mock_resource "aws_iam_instance_profile" {
    defaults = { arn = "arn:aws-manifest:iam::123456789012:instance-profile/manifest-unoverridden" }
  }
}

override_resource {
  target = aws_iam_role.brainstore_deployment_waiter[0]
  values = {
    arn = "arn:aws-manifest:iam::123456789012:role/manifest-brainstore_deployment_waiter"
    id  = "manifest-brainstore_deployment_waiter"
  }
}

override_resource {
  target = aws_iam_role.api_handler[0]
  values = {
    arn = "arn:aws-manifest:iam::123456789012:role/manifest-api_handler"
    id  = "manifest-api_handler"
  }
}

override_resource {
  target = aws_iam_role.brainstore[0]
  values = {
    arn = "arn:aws-manifest:iam::123456789012:role/manifest-brainstore"
    id  = "manifest-brainstore"
  }
}

override_resource {
  target = aws_iam_role.api_ecs_task_execution[0]
  values = {
    arn = "arn:aws-manifest:iam::123456789012:role/manifest-api_ecs_task_execution"
    id  = "manifest-api_ecs_task_execution"
  }
}

override_resource {
  target = aws_iam_role.automation_cron[0]
  values = {
    arn = "arn:aws-manifest:iam::123456789012:role/manifest-automation_cron"
    id  = "manifest-automation_cron"
  }
}

override_resource {
  target = aws_iam_role.quarantine_pruner[0]
  values = {
    arn = "arn:aws-manifest:iam::123456789012:role/manifest-quarantine_pruner"
    id  = "manifest-quarantine_pruner"
  }
}

override_resource {
  target = aws_iam_role.default[0]
  values = {
    arn = "arn:aws-manifest:iam::123456789012:role/manifest-default"
    id  = "manifest-default"
  }
}

override_resource {
  target = aws_iam_role.billing_cron[0]
  values = {
    arn = "arn:aws-manifest:iam::123456789012:role/manifest-billing_cron"
    id  = "manifest-billing_cron"
  }
}

override_resource {
  target = aws_iam_role.catchup_etl[0]
  values = {
    arn = "arn:aws-manifest:iam::123456789012:role/manifest-catchup_etl"
    id  = "manifest-catchup_etl"
  }
}

override_resource {
  target = aws_iam_role.migrate_database[0]
  values = {
    arn = "arn:aws-manifest:iam::123456789012:role/manifest-migrate_database"
    id  = "manifest-migrate_database"
  }
}

override_resource {
  target = aws_iam_role.quarantine_warmup[0]
  values = {
    arn = "arn:aws-manifest:iam::123456789012:role/manifest-quarantine_warmup"
    id  = "manifest-quarantine_warmup"
  }
}

override_resource {
  target = aws_iam_role.gateway_task_execution[0]
  values = {
    arn = "arn:aws-manifest:iam::123456789012:role/manifest-gateway_task_execution"
    id  = "manifest-gateway_task_execution"
  }
}

override_resource {
  target = aws_iam_role.gateway_task[0]
  values = {
    arn = "arn:aws-manifest:iam::123456789012:role/manifest-gateway_task"
    id  = "manifest-gateway_task"
  }
}

override_resource {
  target = aws_iam_role.ai_proxy_invoke[0]
  values = {
    arn = "arn:aws-manifest:iam::123456789012:role/manifest-ai_proxy_invoke"
    id  = "manifest-ai_proxy_invoke"
  }
}

override_resource {
  target = aws_iam_role.db_monitoring[0]
  values = {
    arn = "arn:aws-manifest:iam::123456789012:role/manifest-db_monitoring"
    id  = "manifest-db_monitoring"
  }
}

override_resource {
  target = aws_iam_role.automation_cron_schedule[0]
  values = {
    arn = "arn:aws-manifest:iam::123456789012:role/manifest-automation_cron_schedule"
    id  = "manifest-automation_cron_schedule"
  }
}

override_resource {
  target = aws_iam_role.billing_cron_schedule[0]
  values = {
    arn = "arn:aws-manifest:iam::123456789012:role/manifest-billing_cron_schedule"
    id  = "manifest-billing_cron_schedule"
  }
}

override_resource {
  target = aws_iam_role.catchup_etl_schedule[0]
  values = {
    arn = "arn:aws-manifest:iam::123456789012:role/manifest-catchup_etl_schedule"
    id  = "manifest-catchup_etl_schedule"
  }
}

override_resource {
  target = aws_iam_role.quarantine_pruner_schedule[0]
  values = {
    arn = "arn:aws-manifest:iam::123456789012:role/manifest-quarantine_pruner_schedule"
    id  = "manifest-quarantine_pruner_schedule"
  }
}

override_resource {
  target = aws_iam_role.quarantine_invoke[0]
  values = {
    arn = "arn:aws-manifest:iam::123456789012:role/manifest-quarantine_invoke"
    id  = "manifest-quarantine_invoke"
  }
}

override_resource {
  target = aws_iam_role.quarantine_function[0]
  values = {
    arn = "arn:aws-manifest:iam::123456789012:role/manifest-quarantine_function"
    id  = "manifest-quarantine_function"
  }
}

override_resource {
  target = aws_iam_policy.api_handler[0]
  values = { arn = "arn:aws-manifest:iam::123456789012:policy/manifest-api_handler" }
}

override_resource {
  target = aws_iam_policy.api_handler_quarantine[0]
  values = { arn = "arn:aws-manifest:iam::123456789012:policy/manifest-api_handler_quarantine" }
}

override_resource {
  target = aws_iam_policy.api_handler_lambda_policies[0]
  values = { arn = "arn:aws-manifest:iam::123456789012:policy/manifest-api_handler_lambda_policies" }
}

override_resource {
  target = aws_iam_instance_profile.brainstore[0]
  values = { arn = "arn:aws-manifest:iam::123456789012:instance-profile/manifest-iam-brainstore" }
}

override_data {
  target = data.aws_iam_policy_document.ecs_task_assume_role
  values = { json = "{\"ManifestDocument\":\"data.aws_iam_policy_document.ecs_task_assume_role\"}" }
}

# The baseline: the managed call with ECS ingress and every optional feature on.
run "iam_managed_ecs_mode" {
  command = apply
  module { source = "./modules/iam" }

  variables {
    deployment_name                            = "bt-manifest"
    region                                     = "us-east-1"
    account_id                                 = "123456789012"
    create_iam                                 = true
    enable_ecs_api                             = true
    create_ai_gateway                          = true
    ai_gateway_enable_execute_command          = true
    api_ecs_enable_execute_command             = true
    enable_quarantine_vpc                      = true
    enable_quarantine_pruner                   = true
    enable_brainstore_ec2_ssm                  = true
    brainstore_enable_export                   = true
    diagnostics_transcript_log_group_name      = "/braintrust-byoc/bt-manifest/diagnostics"
    custom_ca_bundle_secret_arn                = "arn:aws-manifest:secretsmanager:us-east-1:123456789012:secret:custom-ca-bundle-AbCdEf"
    custom_ca_bundle_kms_key_arn               = "arn:aws-manifest:kms:us-east-1:123456789012:key/00000000-0000-0000-0000-000000000002"
    existing_attachment_s3_bucket_arn          = "arn:aws-manifest:s3:::existing-attachment-bucket"
    existing_attachment_s3_bucket_kms_key_arn  = "arn:aws-manifest:kms:us-east-1:123456789012:key/00000000-0000-0000-0000-000000000005"
    external_attachment_s3_bucket_arns         = ["arn:aws-manifest:s3:::external-attachment-bucket"]
    external_attachment_s3_bucket_kms_key_arns = ["arn:aws-manifest:kms:us-east-1:210987654321:key/00000000-0000-0000-0000-000000000006"]
    service_additional_policy_arns             = ["arn:aws-manifest:iam::123456789012:policy/service-additional"]
    brainstore_additional_policy_arns          = ["arn:aws-manifest:iam::123456789012:policy/brainstore-additional"]
    s3_export_assume_role_arns                 = ["arn:aws:iam::210987654321:role/braintrust-export"]
    ai_gateway_bedrock_assume_role_arns        = ["arn:aws:iam::210987654321:role/braintrust-bedrock"]
    brainstore_asg_names                       = ["bt-manifest-brainstore-reader-0", "bt-manifest-brainstore-writer-0"]
    brainstore_deployment_log_group_arn        = "arn:aws-manifest:logs:us-east-1:123456789012:log-group:/braintrust/bt-manifest/bt-manifest-BrainstoreDeployment"
    created_resources = {
      kms_key_arn                       = "arn:aws-manifest:kms:us-east-1:123456789012:key/00000000-0000-0000-0000-000000000001"
      database_secret_arn               = "arn:aws-manifest:secretsmanager:us-east-1:123456789012:secret:bt-manifest/DatabaseSecret-AbCdEf"
      database_url_secret_arn           = "arn:aws-manifest:secretsmanager:us-east-1:123456789012:secret:bt-manifest/DatabaseUrl-AbCdEf"
      function_tools_secret_arn         = "arn:aws-manifest:secretsmanager:us-east-1:123456789012:secret:bt-manifest/FunctionToolsSecret-AbCdEf"
      redis_url_secret_arn              = "arn:aws-manifest:secretsmanager:us-east-1:123456789012:secret:bt-manifest/RedisUrl-AbCdEf"
      brainstore_license_key_secret_arn = "arn:aws-manifest:secretsmanager:us-east-1:123456789012:secret:bt-manifest/brainstore/license-key-AbCdEf"
      brainstore_s3_bucket_arn          = "arn:aws-manifest:s3:::bt-manifest-brainstore-0"
      code_bundle_s3_bucket_arn         = "arn:aws-manifest:s3:::bt-manifest-code-bundles-0"
      lambda_responses_s3_bucket_arn    = "arn:aws-manifest:s3:::bt-manifest-lambda-responses-0"
      quarantine_vpc_id                 = "vpc-0000000000000000a"
    }
  }
}

# Changes from iam_managed_ecs_mode: enable_ecs_api is false, so the Lambda ingress policies and the AIProxy invoke role render.
run "iam_managed_lambda_mode" {
  command = apply
  module { source = "./modules/iam" }

  variables {
    deployment_name                            = "bt-manifest"
    region                                     = "us-east-1"
    account_id                                 = "123456789012"
    create_iam                                 = true
    enable_ecs_api                             = false
    create_ai_gateway                          = true
    ai_gateway_enable_execute_command          = true
    api_ecs_enable_execute_command             = true
    enable_quarantine_vpc                      = true
    enable_quarantine_pruner                   = true
    enable_brainstore_ec2_ssm                  = true
    brainstore_enable_export                   = true
    diagnostics_transcript_log_group_name      = "/braintrust-byoc/bt-manifest/diagnostics"
    custom_ca_bundle_secret_arn                = "arn:aws-manifest:secretsmanager:us-east-1:123456789012:secret:custom-ca-bundle-AbCdEf"
    custom_ca_bundle_kms_key_arn               = "arn:aws-manifest:kms:us-east-1:123456789012:key/00000000-0000-0000-0000-000000000002"
    existing_attachment_s3_bucket_arn          = "arn:aws-manifest:s3:::existing-attachment-bucket"
    existing_attachment_s3_bucket_kms_key_arn  = "arn:aws-manifest:kms:us-east-1:123456789012:key/00000000-0000-0000-0000-000000000005"
    external_attachment_s3_bucket_arns         = ["arn:aws-manifest:s3:::external-attachment-bucket"]
    external_attachment_s3_bucket_kms_key_arns = ["arn:aws-manifest:kms:us-east-1:210987654321:key/00000000-0000-0000-0000-000000000006"]
    service_additional_policy_arns             = ["arn:aws-manifest:iam::123456789012:policy/service-additional"]
    brainstore_additional_policy_arns          = ["arn:aws-manifest:iam::123456789012:policy/brainstore-additional"]
    s3_export_assume_role_arns                 = ["arn:aws:iam::210987654321:role/braintrust-export"]
    ai_gateway_bedrock_assume_role_arns        = ["arn:aws:iam::210987654321:role/braintrust-bedrock"]
    brainstore_asg_names                       = ["bt-manifest-brainstore-reader-0", "bt-manifest-brainstore-writer-0"]
    brainstore_deployment_log_group_arn        = "arn:aws-manifest:logs:us-east-1:123456789012:log-group:/braintrust/bt-manifest/bt-manifest-BrainstoreDeployment"
    created_resources = {
      kms_key_arn                       = "arn:aws-manifest:kms:us-east-1:123456789012:key/00000000-0000-0000-0000-000000000001"
      database_secret_arn               = "arn:aws-manifest:secretsmanager:us-east-1:123456789012:secret:bt-manifest/DatabaseSecret-AbCdEf"
      database_url_secret_arn           = "arn:aws-manifest:secretsmanager:us-east-1:123456789012:secret:bt-manifest/DatabaseUrl-AbCdEf"
      function_tools_secret_arn         = "arn:aws-manifest:secretsmanager:us-east-1:123456789012:secret:bt-manifest/FunctionToolsSecret-AbCdEf"
      redis_url_secret_arn              = "arn:aws-manifest:secretsmanager:us-east-1:123456789012:secret:bt-manifest/RedisUrl-AbCdEf"
      brainstore_license_key_secret_arn = "arn:aws-manifest:secretsmanager:us-east-1:123456789012:secret:bt-manifest/brainstore/license-key-AbCdEf"
      brainstore_s3_bucket_arn          = "arn:aws-manifest:s3:::bt-manifest-brainstore-0"
      code_bundle_s3_bucket_arn         = "arn:aws-manifest:s3:::bt-manifest-code-bundles-0"
      lambda_responses_s3_bucket_arn    = "arn:aws-manifest:s3:::bt-manifest-lambda-responses-0"
      quarantine_vpc_id                 = "vpc-0000000000000000a"
    }
  }
}

# Changes from iam_managed_ecs_mode: both AssumeRole lists are empty, so those statements fall back to Resource "*".
run "iam_managed_without_assume_role_lists" {
  command = apply
  module { source = "./modules/iam" }

  variables {
    deployment_name                            = "bt-manifest"
    region                                     = "us-east-1"
    account_id                                 = "123456789012"
    create_iam                                 = true
    enable_ecs_api                             = true
    create_ai_gateway                          = true
    ai_gateway_enable_execute_command          = true
    api_ecs_enable_execute_command             = true
    enable_quarantine_vpc                      = true
    enable_quarantine_pruner                   = true
    enable_brainstore_ec2_ssm                  = true
    brainstore_enable_export                   = true
    diagnostics_transcript_log_group_name      = "/braintrust-byoc/bt-manifest/diagnostics"
    custom_ca_bundle_secret_arn                = "arn:aws-manifest:secretsmanager:us-east-1:123456789012:secret:custom-ca-bundle-AbCdEf"
    custom_ca_bundle_kms_key_arn               = "arn:aws-manifest:kms:us-east-1:123456789012:key/00000000-0000-0000-0000-000000000002"
    existing_attachment_s3_bucket_arn          = "arn:aws-manifest:s3:::existing-attachment-bucket"
    existing_attachment_s3_bucket_kms_key_arn  = "arn:aws-manifest:kms:us-east-1:123456789012:key/00000000-0000-0000-0000-000000000005"
    external_attachment_s3_bucket_arns         = ["arn:aws-manifest:s3:::external-attachment-bucket"]
    external_attachment_s3_bucket_kms_key_arns = ["arn:aws-manifest:kms:us-east-1:210987654321:key/00000000-0000-0000-0000-000000000006"]
    service_additional_policy_arns             = ["arn:aws-manifest:iam::123456789012:policy/service-additional"]
    brainstore_additional_policy_arns          = ["arn:aws-manifest:iam::123456789012:policy/brainstore-additional"]
    s3_export_assume_role_arns                 = []
    ai_gateway_bedrock_assume_role_arns        = []
    brainstore_asg_names                       = ["bt-manifest-brainstore-reader-0", "bt-manifest-brainstore-writer-0"]
    brainstore_deployment_log_group_arn        = "arn:aws-manifest:logs:us-east-1:123456789012:log-group:/braintrust/bt-manifest/bt-manifest-BrainstoreDeployment"
    created_resources = {
      kms_key_arn                       = "arn:aws-manifest:kms:us-east-1:123456789012:key/00000000-0000-0000-0000-000000000001"
      database_secret_arn               = "arn:aws-manifest:secretsmanager:us-east-1:123456789012:secret:bt-manifest/DatabaseSecret-AbCdEf"
      database_url_secret_arn           = "arn:aws-manifest:secretsmanager:us-east-1:123456789012:secret:bt-manifest/DatabaseUrl-AbCdEf"
      function_tools_secret_arn         = "arn:aws-manifest:secretsmanager:us-east-1:123456789012:secret:bt-manifest/FunctionToolsSecret-AbCdEf"
      redis_url_secret_arn              = "arn:aws-manifest:secretsmanager:us-east-1:123456789012:secret:bt-manifest/RedisUrl-AbCdEf"
      brainstore_license_key_secret_arn = "arn:aws-manifest:secretsmanager:us-east-1:123456789012:secret:bt-manifest/brainstore/license-key-AbCdEf"
      brainstore_s3_bucket_arn          = "arn:aws-manifest:s3:::bt-manifest-brainstore-0"
      code_bundle_s3_bucket_arn         = "arn:aws-manifest:s3:::bt-manifest-code-bundles-0"
      lambda_responses_s3_bucket_arn    = "arn:aws-manifest:s3:::bt-manifest-lambda-responses-0"
      quarantine_vpc_id                 = "vpc-0000000000000000a"
    }
  }
}

# Changes from iam_managed_ecs_mode: the caller supplies the KMS key, the Brainstore bucket and its key, and the license secret, so created_resources omits them.
run "iam_managed_caller_resources" {
  command = apply
  module { source = "./modules/iam" }

  variables {
    deployment_name                            = "bt-manifest"
    region                                     = "us-east-1"
    account_id                                 = "123456789012"
    create_iam                                 = true
    enable_ecs_api                             = true
    create_ai_gateway                          = true
    ai_gateway_enable_execute_command          = true
    api_ecs_enable_execute_command             = true
    enable_quarantine_vpc                      = true
    enable_quarantine_pruner                   = true
    enable_brainstore_ec2_ssm                  = true
    brainstore_enable_export                   = true
    diagnostics_transcript_log_group_name      = "/braintrust-byoc/bt-manifest/diagnostics"
    custom_ca_bundle_secret_arn                = "arn:aws-manifest:secretsmanager:us-east-1:123456789012:secret:custom-ca-bundle-AbCdEf"
    custom_ca_bundle_kms_key_arn               = "arn:aws-manifest:kms:us-east-1:123456789012:key/00000000-0000-0000-0000-000000000002"
    existing_attachment_s3_bucket_arn          = "arn:aws-manifest:s3:::existing-attachment-bucket"
    existing_attachment_s3_bucket_kms_key_arn  = "arn:aws-manifest:kms:us-east-1:123456789012:key/00000000-0000-0000-0000-000000000005"
    external_attachment_s3_bucket_arns         = ["arn:aws-manifest:s3:::external-attachment-bucket"]
    external_attachment_s3_bucket_kms_key_arns = ["arn:aws-manifest:kms:us-east-1:210987654321:key/00000000-0000-0000-0000-000000000006"]
    service_additional_policy_arns             = ["arn:aws-manifest:iam::123456789012:policy/service-additional"]
    brainstore_additional_policy_arns          = ["arn:aws-manifest:iam::123456789012:policy/brainstore-additional"]
    s3_export_assume_role_arns                 = ["arn:aws:iam::210987654321:role/braintrust-export"]
    ai_gateway_bedrock_assume_role_arns        = ["arn:aws:iam::210987654321:role/braintrust-bedrock"]
    brainstore_asg_names                       = ["bt-manifest-brainstore-reader-0", "bt-manifest-brainstore-writer-0"]
    brainstore_deployment_log_group_arn        = "arn:aws-manifest:logs:us-east-1:123456789012:log-group:/braintrust/bt-manifest/bt-manifest-BrainstoreDeployment"
    kms_key_arn                                = "arn:aws-manifest:kms:us-east-1:123456789012:key/00000000-0000-0000-0000-000000000001"
    existing_brainstore_s3_bucket_arn          = "arn:aws-manifest:s3:::existing-brainstore-bucket"
    existing_brainstore_s3_bucket_kms_key_arn  = "arn:aws-manifest:kms:us-east-1:123456789012:key/00000000-0000-0000-0000-000000000004"
    existing_brainstore_license_key_secret = {
      arn         = "arn:aws-manifest:secretsmanager:us-east-1:123456789012:secret:existing-license-key-AbCdEf"
      kms_key_arn = "arn:aws-manifest:kms:us-east-1:123456789012:key/00000000-0000-0000-0000-000000000003"
    }
    created_resources = {
      database_secret_arn            = "arn:aws-manifest:secretsmanager:us-east-1:123456789012:secret:bt-manifest/DatabaseSecret-AbCdEf"
      database_url_secret_arn        = "arn:aws-manifest:secretsmanager:us-east-1:123456789012:secret:bt-manifest/DatabaseUrl-AbCdEf"
      function_tools_secret_arn      = "arn:aws-manifest:secretsmanager:us-east-1:123456789012:secret:bt-manifest/FunctionToolsSecret-AbCdEf"
      redis_url_secret_arn           = "arn:aws-manifest:secretsmanager:us-east-1:123456789012:secret:bt-manifest/RedisUrl-AbCdEf"
      code_bundle_s3_bucket_arn      = "arn:aws-manifest:s3:::bt-manifest-code-bundles-0"
      lambda_responses_s3_bucket_arn = "arn:aws-manifest:s3:::bt-manifest-lambda-responses-0"
      quarantine_vpc_id              = "vpc-0000000000000000a"
    }
  }
}

# Changes from iam_managed_ecs_mode: external EKS with Pod Identity and IRSA, scoped to a cluster and namespace.
run "iam_managed_external_eks" {
  command = apply
  module { source = "./modules/iam" }

  variables {
    deployment_name                            = "bt-manifest"
    region                                     = "us-east-1"
    account_id                                 = "123456789012"
    create_iam                                 = true
    enable_ecs_api                             = true
    create_ai_gateway                          = true
    ai_gateway_enable_execute_command          = true
    api_ecs_enable_execute_command             = true
    enable_quarantine_vpc                      = true
    enable_quarantine_pruner                   = true
    enable_brainstore_ec2_ssm                  = true
    brainstore_enable_export                   = true
    diagnostics_transcript_log_group_name      = "/braintrust-byoc/bt-manifest/diagnostics"
    custom_ca_bundle_secret_arn                = "arn:aws-manifest:secretsmanager:us-east-1:123456789012:secret:custom-ca-bundle-AbCdEf"
    custom_ca_bundle_kms_key_arn               = "arn:aws-manifest:kms:us-east-1:123456789012:key/00000000-0000-0000-0000-000000000002"
    existing_attachment_s3_bucket_arn          = "arn:aws-manifest:s3:::existing-attachment-bucket"
    existing_attachment_s3_bucket_kms_key_arn  = "arn:aws-manifest:kms:us-east-1:123456789012:key/00000000-0000-0000-0000-000000000005"
    external_attachment_s3_bucket_arns         = ["arn:aws-manifest:s3:::external-attachment-bucket"]
    external_attachment_s3_bucket_kms_key_arns = ["arn:aws-manifest:kms:us-east-1:210987654321:key/00000000-0000-0000-0000-000000000006"]
    service_additional_policy_arns             = ["arn:aws-manifest:iam::123456789012:policy/service-additional"]
    brainstore_additional_policy_arns          = ["arn:aws-manifest:iam::123456789012:policy/brainstore-additional"]
    s3_export_assume_role_arns                 = ["arn:aws:iam::210987654321:role/braintrust-export"]
    ai_gateway_bedrock_assume_role_arns        = ["arn:aws:iam::210987654321:role/braintrust-bedrock"]
    brainstore_asg_names                       = ["bt-manifest-brainstore-reader-0", "bt-manifest-brainstore-writer-0"]
    brainstore_deployment_log_group_arn        = "arn:aws-manifest:logs:us-east-1:123456789012:log-group:/braintrust/bt-manifest/bt-manifest-BrainstoreDeployment"
    use_deployment_mode_external_eks           = true
    enable_eks_pod_identity                    = true
    enable_eks_irsa                            = true
    eks_cluster_arn                            = "arn:aws-manifest:eks:us-east-1:123456789012:cluster/bt-manifest"
    eks_namespace                              = "manifest-namespace"
    created_resources = {
      kms_key_arn                       = "arn:aws-manifest:kms:us-east-1:123456789012:key/00000000-0000-0000-0000-000000000001"
      database_secret_arn               = "arn:aws-manifest:secretsmanager:us-east-1:123456789012:secret:bt-manifest/DatabaseSecret-AbCdEf"
      database_url_secret_arn           = "arn:aws-manifest:secretsmanager:us-east-1:123456789012:secret:bt-manifest/DatabaseUrl-AbCdEf"
      function_tools_secret_arn         = "arn:aws-manifest:secretsmanager:us-east-1:123456789012:secret:bt-manifest/FunctionToolsSecret-AbCdEf"
      redis_url_secret_arn              = "arn:aws-manifest:secretsmanager:us-east-1:123456789012:secret:bt-manifest/RedisUrl-AbCdEf"
      brainstore_license_key_secret_arn = "arn:aws-manifest:secretsmanager:us-east-1:123456789012:secret:bt-manifest/brainstore/license-key-AbCdEf"
      brainstore_s3_bucket_arn          = "arn:aws-manifest:s3:::bt-manifest-brainstore-0"
      code_bundle_s3_bucket_arn         = "arn:aws-manifest:s3:::bt-manifest-code-bundles-0"
      lambda_responses_s3_bucket_arn    = "arn:aws-manifest:s3:::bt-manifest-lambda-responses-0"
      quarantine_vpc_id                 = "vpc-0000000000000000a"
    }
  }
}

# Not based on iam_managed_ecs_mode: external EKS with Pod Identity only, no optional features, and no IRSA, cluster or namespace.
run "iam_managed_external_eks_pod_identity_only" {
  command = apply
  module { source = "./modules/iam" }

  variables {
    deployment_name                  = "bt-manifest"
    region                           = "us-east-1"
    account_id                       = "123456789012"
    use_deployment_mode_external_eks = true
    enable_eks_pod_identity          = true
    created_resources = {
      kms_key_arn                       = "arn:aws-manifest:kms:us-east-1:123456789012:key/00000000-0000-0000-0000-000000000001"
      database_secret_arn               = "arn:aws-manifest:secretsmanager:us-east-1:123456789012:secret:bt-manifest/DatabaseSecret-AbCdEf"
      database_url_secret_arn           = "arn:aws-manifest:secretsmanager:us-east-1:123456789012:secret:bt-manifest/DatabaseUrl-AbCdEf"
      function_tools_secret_arn         = "arn:aws-manifest:secretsmanager:us-east-1:123456789012:secret:bt-manifest/FunctionToolsSecret-AbCdEf"
      redis_url_secret_arn              = "arn:aws-manifest:secretsmanager:us-east-1:123456789012:secret:bt-manifest/RedisUrl-AbCdEf"
      brainstore_license_key_secret_arn = "arn:aws-manifest:secretsmanager:us-east-1:123456789012:secret:bt-manifest/brainstore/license-key-AbCdEf"
      brainstore_s3_bucket_arn          = "arn:aws-manifest:s3:::bt-manifest-brainstore-0"
      code_bundle_s3_bucket_arn         = "arn:aws-manifest:s3:::bt-manifest-code-bundles-0"
      lambda_responses_s3_bucket_arn    = "arn:aws-manifest:s3:::bt-manifest-lambda-responses-0"
      quarantine_vpc_id                 = "vpc-0000000000000000a"
    }
  }
}

# Changes from iam_managed_ecs_mode: the standalone call, with no created_resources, so policies scope module-created resources by prefix, alias and tag.
run "iam_standalone_module_resources" {
  command = apply
  module { source = "./modules/iam" }

  variables {
    deployment_name                            = "bt-manifest"
    region                                     = "us-east-1"
    account_id                                 = "123456789012"
    create_iam                                 = true
    enable_ecs_api                             = true
    create_ai_gateway                          = true
    ai_gateway_enable_execute_command          = true
    api_ecs_enable_execute_command             = true
    enable_quarantine_vpc                      = true
    enable_quarantine_pruner                   = true
    enable_brainstore_ec2_ssm                  = true
    brainstore_enable_export                   = true
    diagnostics_transcript_log_group_name      = "/braintrust-byoc/bt-manifest/diagnostics"
    custom_ca_bundle_secret_arn                = "arn:aws-manifest:secretsmanager:us-east-1:123456789012:secret:custom-ca-bundle-AbCdEf"
    custom_ca_bundle_kms_key_arn               = "arn:aws-manifest:kms:us-east-1:123456789012:key/00000000-0000-0000-0000-000000000002"
    existing_attachment_s3_bucket_arn          = "arn:aws-manifest:s3:::existing-attachment-bucket"
    existing_attachment_s3_bucket_kms_key_arn  = "arn:aws-manifest:kms:us-east-1:123456789012:key/00000000-0000-0000-0000-000000000005"
    external_attachment_s3_bucket_arns         = ["arn:aws-manifest:s3:::external-attachment-bucket"]
    external_attachment_s3_bucket_kms_key_arns = ["arn:aws-manifest:kms:us-east-1:210987654321:key/00000000-0000-0000-0000-000000000006"]
    service_additional_policy_arns             = ["arn:aws-manifest:iam::123456789012:policy/service-additional"]
    brainstore_additional_policy_arns          = ["arn:aws-manifest:iam::123456789012:policy/brainstore-additional"]
    s3_export_assume_role_arns                 = ["arn:aws:iam::210987654321:role/braintrust-export"]
    ai_gateway_bedrock_assume_role_arns        = ["arn:aws:iam::210987654321:role/braintrust-bedrock"]
    brainstore_asg_names                       = ["bt-manifest-brainstore-reader-0", "bt-manifest-brainstore-writer-0"]
    brainstore_deployment_log_group_arn        = "arn:aws-manifest:logs:us-east-1:123456789012:log-group:/braintrust/bt-manifest/bt-manifest-BrainstoreDeployment"
    iam_owner                                  = "customer"
    existing_quarantine_vpc_id                 = "vpc-0000000000000000a"
  }
}

# Changes from iam_standalone_module_resources: the caller supplies the KMS key, the Brainstore bucket and its key, the license secret and the Postgres override secret.
run "iam_standalone_caller_resources" {
  command = apply
  module { source = "./modules/iam" }

  variables {
    deployment_name                            = "bt-manifest"
    region                                     = "us-east-1"
    account_id                                 = "123456789012"
    create_iam                                 = true
    enable_ecs_api                             = true
    create_ai_gateway                          = true
    ai_gateway_enable_execute_command          = true
    api_ecs_enable_execute_command             = true
    enable_quarantine_vpc                      = true
    enable_quarantine_pruner                   = true
    enable_brainstore_ec2_ssm                  = true
    brainstore_enable_export                   = true
    diagnostics_transcript_log_group_name      = "/braintrust-byoc/bt-manifest/diagnostics"
    custom_ca_bundle_secret_arn                = "arn:aws-manifest:secretsmanager:us-east-1:123456789012:secret:custom-ca-bundle-AbCdEf"
    custom_ca_bundle_kms_key_arn               = "arn:aws-manifest:kms:us-east-1:123456789012:key/00000000-0000-0000-0000-000000000002"
    existing_attachment_s3_bucket_arn          = "arn:aws-manifest:s3:::existing-attachment-bucket"
    existing_attachment_s3_bucket_kms_key_arn  = "arn:aws-manifest:kms:us-east-1:123456789012:key/00000000-0000-0000-0000-000000000005"
    external_attachment_s3_bucket_arns         = ["arn:aws-manifest:s3:::external-attachment-bucket"]
    external_attachment_s3_bucket_kms_key_arns = ["arn:aws-manifest:kms:us-east-1:210987654321:key/00000000-0000-0000-0000-000000000006"]
    service_additional_policy_arns             = ["arn:aws-manifest:iam::123456789012:policy/service-additional"]
    brainstore_additional_policy_arns          = ["arn:aws-manifest:iam::123456789012:policy/brainstore-additional"]
    s3_export_assume_role_arns                 = ["arn:aws:iam::210987654321:role/braintrust-export"]
    ai_gateway_bedrock_assume_role_arns        = ["arn:aws:iam::210987654321:role/braintrust-bedrock"]
    brainstore_asg_names                       = ["bt-manifest-brainstore-reader-0", "bt-manifest-brainstore-writer-0"]
    brainstore_deployment_log_group_arn        = "arn:aws-manifest:logs:us-east-1:123456789012:log-group:/braintrust/bt-manifest/bt-manifest-BrainstoreDeployment"
    iam_owner                                  = "customer"
    existing_quarantine_vpc_id                 = "vpc-0000000000000000a"
    kms_key_arn                                = "arn:aws-manifest:kms:us-east-1:123456789012:key/00000000-0000-0000-0000-000000000001"
    existing_brainstore_s3_bucket_arn          = "arn:aws-manifest:s3:::existing-brainstore-bucket"
    existing_brainstore_s3_bucket_kms_key_arn  = "arn:aws-manifest:kms:us-east-1:123456789012:key/00000000-0000-0000-0000-000000000004"
    existing_brainstore_license_key_secret = {
      arn         = "arn:aws-manifest:secretsmanager:us-east-1:123456789012:secret:existing-license-key-AbCdEf"
      kms_key_arn = "arn:aws-manifest:kms:us-east-1:123456789012:key/00000000-0000-0000-0000-000000000003"
    }
    use_postgres_connection_override                    = true
    postgres_connection_override_credentials_secret_arn = "arn:aws-manifest:secretsmanager:us-east-1:123456789012:secret:postgres-credentials-AbCdEf"
  }
}
