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

run "complete_rollout" {
  command = apply
  module { source = "./modules/brainstore-deployment" }

  assert {
    condition     = jsondecode(aws_lambda_invocation.first.input).deployment.fleets == jsondecode(aws_lambda_invocation.final.input).deployment.fleets
    error_message = "Every slice must check the same exact fleet configuration."
  }
  assert {
    condition     = jsondecode(aws_lambda_invocation.second.input).continuation == jsondecode(aws_lambda_invocation.first.result).continuation && jsondecode(aws_lambda_invocation.final.input).continuation == jsondecode(aws_lambda_invocation.second.result).continuation
    error_message = "Each invocation must resume the previous slice's progress."
  }
  assert {
    condition     = jsondecode(aws_lambda_invocation.final.input).final && !jsondecode(aws_lambda_invocation.first.input).final && aws_lambda_function.waiter.timeout > jsondecode(aws_lambda_invocation.final.input).wait_seconds
    error_message = "Only the final slice must require completion, with time left to report failure."
  }
  assert {
    condition     = jsondecode(aws_iam_role_policy.waiter.policy).Statement[1].Resource[0] == "arn:aws:autoscaling:us-east-1:123456789012:autoScalingGroup:*:autoScalingGroupName/bt-test-brainstore-123" && jsondecode(aws_iam_role_policy.waiter.policy).Statement[1].Condition.StringEquals["autoscaling:ResourceTag/BraintrustDeploymentName"] == "bt-test"
    error_message = "Refresh permissions must be scoped to this deployment's named and tagged ASGs."
  }
  assert {
    condition     = length(aws_lambda_function.waiter.vpc_config) == 0 && aws_lambda_function.waiter.tags.BraintrustDeploymentName == "bt-test"
    error_message = "The deployment function must be tagged and independent of dataplane VPC connectivity."
  }
}

run "reject_missing_artifact" {
  command = plan
  module { source = "./modules/brainstore-deployment" }
  override_data {
    target = data.http.artifact
    values = { status_code = 404, response_body = "missing" }
  }
  expect_failures = [data.http.artifact]
}
