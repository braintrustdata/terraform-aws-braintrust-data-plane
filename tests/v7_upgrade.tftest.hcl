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
