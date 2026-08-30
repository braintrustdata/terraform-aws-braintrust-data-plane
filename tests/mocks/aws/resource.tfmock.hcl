# Valid shared resource defaults for stateful root-module tests. Provider
# generated random strings are not sufficient for downstream ARN validation.

mock_resource "aws_lb" {
  defaults = {
    arn        = "arn:aws:elasticloadbalancing:us-east-1:123456789012:loadbalancer/app/mock/1234567890abcdef"
    arn_suffix = "app/mock/1234567890abcdef"
    dns_name   = "mock.us-east-1.elb.amazonaws.com"
    zone_id    = "Z35SXDOTRQ7X7K"
  }
}

mock_resource "aws_lb_target_group" {
  defaults = {
    arn        = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/mock/1234567890abcdef"
    arn_suffix = "targetgroup/mock/1234567890abcdef"
  }
}

mock_resource "aws_lb_listener" {
  defaults = {
    arn = "arn:aws:elasticloadbalancing:us-east-1:123456789012:listener/app/mock/1234567890abcdef/1234567890abcdef"
  }
}

mock_resource "aws_s3_bucket" {
  defaults = {
    arn    = "arn:aws:s3:::mock-bucket"
    bucket = "mock-bucket"
    id     = "mock-bucket"
  }
}

mock_resource "aws_lambda_function" {
  defaults = {
    arn           = "arn:aws:lambda:us-east-1:123456789012:function:mock-function"
    function_name = "mock-function"
  }
}

mock_resource "aws_cloudwatch_event_rule" {
  defaults = {
    arn = "arn:aws:events:us-east-1:123456789012:rule/mock-rule"
  }
}

mock_resource "aws_appautoscaling_policy" {
  defaults = {
    arn = "arn:aws:sns:us-east-1:123456789012:mock-scaling-action"
  }
}

mock_resource "aws_iam_role" {
  defaults = {
    arn  = "arn:aws:iam::123456789012:role/mock-role"
    id   = "mock-role"
    name = "mock-role"
  }
}

mock_resource "aws_iam_instance_profile" {
  defaults = {
    arn  = "arn:aws:iam::123456789012:instance-profile/mock-instance-profile"
    name = "mock-instance-profile"
  }
}

mock_resource "aws_launch_template" {
  defaults = {
    id             = "lt-0123456789abcdef0"
    latest_version = 1
  }
}

mock_resource "aws_iam_policy" {
  defaults = {
    arn = "arn:aws:iam::123456789012:policy/mock-policy"
  }
}

mock_resource "aws_kms_key" {
  defaults = {
    arn    = "arn:aws:kms:us-east-1:123456789012:key/00000000-0000-0000-0000-000000000000"
    key_id = "00000000-0000-0000-0000-000000000000"
  }
}

mock_resource "aws_elasticache_cluster" {
  defaults = {
    cache_nodes = [{
      address               = "mock-cache.example.test"
      availability_zone     = "us-east-1a"
      id                    = "0001"
      outpost_arn           = null
      port                  = 6379
      preferred_outpost_arn = null
    }]
  }
}
