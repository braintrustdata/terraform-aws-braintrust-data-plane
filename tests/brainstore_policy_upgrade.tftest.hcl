mock_provider "aws" {
  source = "./tests/mocks/aws"
  mock_resource "aws_iam_policy" {
    defaults = { arn = "arn:aws:iam::123456789012:policy/test" }
  }
  mock_resource "aws_lb" {
    defaults = { arn = "arn:aws:elasticloadbalancing:us-east-1:123456789012:loadbalancer/net/bt-test/1234567890123456" }
  }
  mock_resource "aws_lb_target_group" {
    defaults = { arn = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/bt-test/1234567890123456" }
  }
  mock_resource "aws_iam_instance_profile" {
    defaults = { arn = "arn:aws:iam::123456789012:instance-profile/bt-test" }
  }
  mock_resource "aws_launch_template" {
    defaults = { id = "lt-0123456789abcdef0", latest_version = 1 }
  }
}

run "baseline" {
  # The mock provider creates no AWS resources.
  command = apply
  module { source = "./tests/fixtures/brainstore-policy-upgrade" }
  providers = { aws = aws }
}

run "api_policy_change_preserves_brainstore_templates" {
  command = plan
  module { source = "./tests/fixtures/brainstore-policy-upgrade" }
  providers = { aws = aws }
  variables {
    service_additional_policy_arns = ["arn:aws:iam::123456789012:policy/api-only"]
  }
  assert {
    condition     = output.deployment_fleets == run.baseline.deployment_fleets
    error_message = "An API-only policy change must preserve Brainstore launch template versions."
  }
}
