mock_provider "aws" {
  source = "./tests/mocks/aws"
}

variables {
  deployment_name = "bt-test"
  kms_key_arn     = "arn:aws:kms:us-east-1:123456789012:key/11111111-1111-1111-1111-111111111111"
}

run "default_preserves_logging" {
  command = plan
  module { source = "./modules/ecs" }
  assert {
    condition     = aws_ecs_cluster.dataplane.configuration[0].execute_command_configuration[0].logging == "DEFAULT"
    error_message = "Unset transcript input must preserve existing cluster logging."
  }
  assert {
    condition     = length(aws_ecs_cluster.dataplane.configuration[0].execute_command_configuration[0].log_configuration) == 0
    error_message = "Unset input must not add a transcript destination."
  }
}

run "protected_destination" {
  command = plan
  module { source = "./modules/ecs" }
  variables {
    diagnostics_transcript_log_group_name = "/braintrust-byoc/test/diagnostics"
  }
  assert {
    condition     = aws_ecs_cluster.dataplane.configuration[0].execute_command_configuration[0].logging == "OVERRIDE"
    error_message = "Opt-in must override the per-container application log destination."
  }
  assert {
    condition     = aws_ecs_cluster.dataplane.configuration[0].execute_command_configuration[0].log_configuration[0].cloud_watch_log_group_name == "/braintrust-byoc/test/diagnostics"
    error_message = "Use only the specified existing group."
  }
  assert {
    condition     = aws_ecs_cluster.dataplane.configuration[0].execute_command_configuration[0].kms_key_id == var.kms_key_arn
    error_message = "Transcript selection must not change existing ECS Exec session encryption."
  }
}

run "wildcard_rejected" {
  command = plan
  module { source = "./modules/ecs" }
  variables { diagnostics_transcript_log_group_name = "/braintrust/*" }
  expect_failures = [var.diagnostics_transcript_log_group_name]
}
