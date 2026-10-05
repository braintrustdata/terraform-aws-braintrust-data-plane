mock_provider "aws" {
  source = "./tests/mocks/aws"
  mock_data "aws_partition" {
    defaults = { partition = "aws" }
  }
}
variables {
  deployment_name                = "bt-test"
  vpc_id                         = "vpc-12345678"
  kms_key_arn                    = "arn:aws:kms:us-east-1:123456789012:key/00000000-0000-0000-0000-000000000000"
  brainstore_s3_bucket_arn       = "arn:aws:s3:::bt-test-brainstore"
  database_secret_arn            = "arn:aws:secretsmanager:us-east-1:123456789012:secret:bt-test-database"
  code_bundle_s3_bucket_arn      = "arn:aws:s3:::bt-test-code-bundles"
  lambda_responses_s3_bucket_arn = "arn:aws:s3:::bt-test-lambda-responses"
  enable_quarantine_vpc          = false
}
run "default_creates_no_transcript_grant" {
  command = plan
  module { source = "./modules/services-common" }
  variables {
    enable_brainstore_ec2_ssm = true
    enable_ecs                = true
  }
  assert {
    condition     = length(aws_iam_role_policy.brainstore_diagnostics_transcripts) == 0 && length(aws_iam_role_policy.api_diagnostics_transcripts) == 0
    error_message = "Default must not broaden workload permissions."
  }
}
run "exact_destination_only" {
  command = plan
  module { source = "./modules/services-common" }
  variables {
    diagnostics_transcript_log_group_name = "/braintrust-byoc/test/diagnostics"
    enable_brainstore_ec2_ssm             = true
    enable_ecs                            = true
  }
  assert {
    condition     = jsondecode(aws_iam_role_policy.brainstore_diagnostics_transcripts[0].policy).Statement[1].Resource == "arn:aws:logs:us-east-1:123456789012:log-group:/braintrust-byoc/test/diagnostics:*"
    error_message = "Brainstore delivery must be restricted to the exact group."
  }
  assert {
    condition     = toset(jsondecode(aws_iam_role_policy.api_diagnostics_transcripts[0].policy).Statement[1].Action) == toset(["logs:CreateLogStream", "logs:DescribeLogStreams", "logs:PutLogEvents"])
    error_message = "Workload delivery must not create/delete log groups or read transcripts."
  }
}
run "disabled_sessions_create_no_grants" {
  command = plan
  module { source = "./modules/services-common" }
  variables { diagnostics_transcript_log_group_name = "/braintrust-byoc/test/diagnostics" }
  assert {
    condition     = length(aws_iam_role_policy.brainstore_diagnostics_transcripts) == 0 && length(aws_iam_role_policy.api_diagnostics_transcripts) == 0
    error_message = "Destination must not silently enable sessions."
  }
}
