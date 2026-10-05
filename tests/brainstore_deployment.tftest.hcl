mock_provider "aws" {
  source = "./tests/mocks/aws"
  mock_data "aws_partition" {
    defaults = { partition = "aws" }
  }
  mock_resource "aws_iam_role" {
    defaults = { arn = "arn:aws:iam::123456789012:role/bt-test-brainstore-deployment" }
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
    condition     = endswith(data.http.artifact.url, "/lambda/BrainstoreDeployment/version-test-api-version")
    error_message = "The deployment helper must use the supplied API release tag."
  }

  assert {
    condition = aws_lambda_invocation.rollout.input == jsonencode({
      deployment = {
        schema_version  = 1
        deployment_name = var.deployment_name
        fleets          = var.fleets
      }
      wait_seconds      = 900
      return_on_timeout = true
    })
    error_message = "The first invocation must allow a timeout response so Terraform can retry."
  }
  assert {
    condition     = output.completion_id == aws_lambda_invocation.retry.id && jsondecode(aws_lambda_invocation.retry.result).status == "complete"
    error_message = "The completion dependency must use the invocation that returns the helper's actual complete-only response."
  }
  assert {
    condition     = jsondecode(aws_lambda_invocation.retry.input).deployment == jsondecode(aws_lambda_invocation.rollout.input).deployment && jsondecode(aws_lambda_invocation.retry.input).wait_seconds == 900 && !can(jsondecode(aws_lambda_invocation.retry.input).return_on_timeout)
    error_message = "The final invocation must use the same deployment and wait budget, throwing on timeout."
  }
  assert {
    condition     = aws_lambda_function.waiter.timeout == 900 && aws_lambda_function.waiter.timeout == jsondecode(aws_lambda_invocation.rollout.input).wait_seconds
    error_message = "Each invocation must use the full 15-minute Lambda limit; the helper retains its runtime guard."
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

run "unchanged_rollout" {
  command = plan
  module { source = "./modules/brainstore-deployment" }

  assert {
    condition     = output.completion_id == run.complete_rollout.completion_id
    error_message = "An unchanged plan must preserve the completed invocation."
  }
}

run "helper_code_update" {
  command = plan
  module { source = "./modules/brainstore-deployment" }
  variables {
    version_tag = "new-api-version"
  }
  override_data {
    target = data.http.artifact
    values = { status_code = 200, response_body = "lambda/BrainstoreDeployment/versions/abcdef.zip" }
  }

  assert {
    condition     = aws_lambda_function.waiter.s3_key == "lambda/BrainstoreDeployment/versions/abcdef.zip"
    error_message = "The helper code must still follow the selected API release."
  }
  assert {
    condition     = aws_lambda_invocation.rollout.qualifier == "$LATEST" && output.completion_id == run.complete_rollout.completion_id
    error_message = "Updating only the helper code must preserve the completed rollout invocation."
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

run "changed_launch_template" {
  command = apply
  module { source = "./modules/brainstore-deployment" }
  variables {
    fleets = [{
      role                    = "reader"
      asg_name                = "bt-test-brainstore-123"
      launch_template_id      = "lt-abc123"
      launch_template_version = "3"
      desired_capacity        = 2
      target_group_arn        = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/reader/abc123"
    }]
  }
  assert {
    condition     = output.completion_id != run.complete_rollout.completion_id && jsondecode(aws_lambda_invocation.retry.input).deployment.fleets[0].launch_template_version == "3"
    error_message = "Changing the deployment must replace the final invocation and send the new launch template."
  }
}
