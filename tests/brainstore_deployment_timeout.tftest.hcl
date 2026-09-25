mock_provider "aws" {
  source = "./tests/mocks/aws"
  mock_data "aws_partition" {
    defaults = { partition = "aws" }
  }
  mock_resource "aws_iam_role" {
    defaults = { arn = "arn:aws:iam::123456789012:role/bt-test-brainstore-deployment" }
  }
  mock_resource "aws_lambda_function" {
    defaults = { version = "1" }
  }
  mock_resource "aws_lambda_invocation" {
    defaults = {
      result = "{\"status\":\"complete\",\"continuation\":{\"deployment_id\":\"test\",\"fleets\":{}}}"
    }
  }
}
mock_provider "http" {
  source = "./tests/mocks/http"
}

variables {
  deployment_name = "bt-test"
  fleets = [{
    role                    = "reader"
    asg_name                = "bt-test-brainstore-123"
    launch_template_id      = "lt-abc123"
    launch_template_version = "2"
    desired_capacity        = 2
    target_group_arn        = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/reader/abc123"
  }]
}

run "reject_incomplete_final_slice" {
  command = apply
  module { source = "./modules/brainstore-deployment" }
  variables {
    deployment_name = "bt-timeout"
  }
  override_resource {
    target = aws_lambda_invocation.final
    values = { result = "{\"status\":\"pending\",\"continuation\":{}}" }
  }
  expect_failures = [aws_lambda_invocation.final]
}
