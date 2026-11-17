mock_provider "aws" {
  source = "./tests/mocks/aws"
  mock_resource "aws_lambda_function" {
    defaults = { version = "1" }
  }
  mock_resource "aws_lambda_invocation" {
    defaults = {
      result = "{\"status\":\"complete\"}"
    }
  }
}
mock_provider "http" {
  source = "./tests/mocks/http"
}

variables {
  deployment_name = "bt-test"
  version_tag     = "test-api-version"
  waiter_role_arn = "arn:aws:iam::123456789012:role/bt-test-brainstore-deployment"
  fleets = [{
    role                    = "reader"
    asg_name                = "bt-test-brainstore-123"
    launch_template_id      = "lt-abc123"
    launch_template_version = "2"
    desired_capacity        = 2
    target_group_arn        = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/reader/abc123"
  }]
}

run "reject_unexpected_response" {
  command = apply
  module { source = "./modules/brainstore-deployment" }
  variables {
    deployment_name = "bt-unexpected"
  }
  override_resource {
    target = aws_lambda_invocation.rollout
    values = { result = "{\"status\":\"pending\"}" }
  }
  expect_failures = [aws_lambda_invocation.rollout]
}
