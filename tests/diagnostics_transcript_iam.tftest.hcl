mock_provider "aws" {
  source = "./tests/mocks/aws"
  mock_data "aws_partition" {
    defaults = { partition = "aws" }
  }
}
variables {
  deployment_name   = "bt-test"
  create_ai_gateway = false

  created_resources = {
    kms_key_arn                       = "arn:aws:kms:us-east-1:123456789012:key/00000000-0000-0000-0000-000000000000"
    database_secret_arn               = "arn:aws:secretsmanager:us-east-1:123456789012:secret:bt-test-database"
    database_url_secret_arn           = "arn:aws:secretsmanager:us-east-1:123456789012:secret:bt-test-database-url"
    function_tools_secret_arn         = "arn:aws:secretsmanager:us-east-1:123456789012:secret:function-tools"
    redis_url_secret_arn              = "arn:aws:secretsmanager:us-east-1:123456789012:secret:redis"
    brainstore_license_key_secret_arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:license"
    brainstore_s3_bucket_arn          = "arn:aws:s3:::bt-test-brainstore"
    code_bundle_s3_bucket_arn         = "arn:aws:s3:::bt-test-code-bundles"
    lambda_responses_s3_bucket_arn    = "arn:aws:s3:::bt-test-lambda-responses"
  }

  brainstore_deployment_log_group_arn = "arn:aws:logs:us-east-1:123456789012:log-group:/braintrust/bt-test/bt-test-BrainstoreDeployment"
  brainstore_asg_names                = ["bt-test-brainstore-reader-123"]
}

run "default_creates_no_transcript_grant" {
  command = plan
  module { source = "./modules/iam" }
  variables {
    enable_brainstore_ec2_ssm      = true
    api_ecs_enable_execute_command = true
  }
  assert {
    condition     = length(aws_iam_role_policy.brainstore_diagnostics_transcripts) == 0 && length(aws_iam_role_policy.api_handler_diagnostics_transcripts) == 0
    error_message = "Default must not broaden workload permissions."
  }
}
run "exact_destination_only" {
  command = plan
  module { source = "./modules/iam" }
  variables {
    diagnostics_transcript_log_group_name = "/braintrust-byoc/test/diagnostics"
    enable_brainstore_ec2_ssm             = true
    api_ecs_enable_execute_command        = true
  }
  assert {
    condition     = jsondecode(aws_iam_role_policy.brainstore_diagnostics_transcripts[0].policy).Statement[1].Resource == "arn:aws:logs:us-east-1:123456789012:log-group:/braintrust-byoc/test/diagnostics:*"
    error_message = "Brainstore delivery must be restricted to the exact group."
  }
  assert {
    condition     = toset(jsondecode(aws_iam_role_policy.api_handler_diagnostics_transcripts[0].policy).Statement[1].Action) == toset(["logs:CreateLogStream", "logs:DescribeLogStreams", "logs:PutLogEvents"])
    error_message = "Workload delivery must not create/delete log groups or read transcripts."
  }
  assert {
    condition     = jsondecode(aws_iam_role_policy.api_handler_diagnostics_transcripts[0].policy).Statement[1].Resource == "arn:aws:logs:us-east-1:123456789012:log-group:/braintrust-byoc/test/diagnostics:*"
    error_message = "API delivery must be restricted to the exact group."
  }
}
run "disabled_sessions_create_no_grants" {
  command = plan
  module { source = "./modules/iam" }
  variables { diagnostics_transcript_log_group_name = "/braintrust-byoc/test/diagnostics" }
  assert {
    condition     = length(aws_iam_role_policy.brainstore_diagnostics_transcripts) == 0 && length(aws_iam_role_policy.api_handler_diagnostics_transcripts) == 0
    error_message = "Destination must not silently enable sessions."
  }
}

run "api_ecs_without_exec_creates_no_transcript_grant" {
  command = plan
  module { source = "./modules/iam" }
  variables {
    diagnostics_transcript_log_group_name = "/braintrust-byoc/test/diagnostics"
    enable_brainstore_ec2_ssm             = true
  }
  assert {
    condition     = length(aws_iam_role_policy.api_handler_diagnostics_transcripts) == 0
    error_message = "API ECS presence must not grant transcript delivery when API Exec is disabled."
  }
  assert {
    condition     = length(aws_iam_role_policy.brainstore_diagnostics_transcripts) == 1
    error_message = "Brainstore transcript delivery must remain independent of API Exec."
  }
  assert {
    condition = length([
      for statement in jsondecode(aws_iam_role.api_handler[0].assume_role_policy).Statement : statement
      if try(statement.Principal.Service, null) == "ecs-tasks.amazonaws.com"
    ]) == 1
    error_message = "Disabling API Exec must not remove the existing ECS task trust."
  }
  assert {
    condition = length([
      for statement in jsondecode(aws_iam_policy.api_handler[0].policy).Statement : statement
      if try(statement.Sid, null) == "ECSExec"
    ]) == 1
    error_message = "The transcript gate must not change existing ECS Exec channel permissions."
  }
}

run "api_exec_without_ecs_creates_no_transcript_grant" {
  command = plan
  module { source = "./modules/iam" }
  variables {
    use_deployment_mode_external_eks      = true
    diagnostics_transcript_log_group_name = "/braintrust-byoc/test/diagnostics"
    api_ecs_enable_execute_command        = true
  }
  assert {
    condition     = length(aws_iam_role_policy.api_handler_diagnostics_transcripts) == 0
    error_message = "An API Exec flag without API ECS must not grant transcript delivery."
  }
}

run "api_exec_does_not_grant_brainstore_transcript_delivery" {
  command = plan
  module { source = "./modules/iam" }
  variables {
    diagnostics_transcript_log_group_name = "/braintrust-byoc/test/diagnostics"
    api_ecs_enable_execute_command        = true
  }
  assert {
    condition     = length(aws_iam_role_policy.api_handler_diagnostics_transcripts) == 1 && length(aws_iam_role_policy.brainstore_diagnostics_transcripts) == 0
    error_message = "API transcript delivery must not grant Brainstore delivery when Brainstore SSM is disabled."
  }
}
