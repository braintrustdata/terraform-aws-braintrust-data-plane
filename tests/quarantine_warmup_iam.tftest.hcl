mock_provider "aws" {
  source = "./tests/mocks/aws"
}
mock_provider "random" {}
mock_provider "http" {
  source = "./tests/mocks/http"
}

variables {
  braintrust_org_name            = "test-org"
  deployment_name                = "bt-test"
  vpc_id                         = "vpc-12345678"
  service_subnet_ids             = ["subnet-11111111", "subnet-22222222", "subnet-33333333"]
  postgres_username              = "test-user"
  postgres_password              = "test-password"
  postgres_host                  = "postgres.internal"
  use_redis_replication_group    = false
  redis_host                     = "redis.internal"
  redis_port                     = "6379"
  whitelisted_origins            = []
  code_bundle_bucket_arn         = "arn:aws:s3:::bt-test-code-bundles"
  lambda_responses_bucket_arn    = "arn:aws:s3:::bt-test-lambda-responses"
  api_security_group_id          = "sg-12345678"
  function_tools_secret_key      = "test-key"
  api_handler_role_arn           = "arn:aws:iam::123456789012:role/bt-test-APIHandlerRole"
  lambda_version_tag_override    = "test-version"
  use_quarantine_vpc             = true
  quarantine_vpc_id              = "vpc-87654321"
  quarantine_vpc_private_subnets = ["subnet-44444444", "subnet-55555555", "subnet-66666666"]
  quarantine_function_role_arn   = "arn:aws:iam::123456789012:role/bt-test-QuarantineFunctionRole"
  permissions_boundary_arn       = "arn:aws:iam::123456789012:policy/boundary"
}

run "warmup_permissions_are_scoped" {
  command = plan
  module {
    source = "./modules/services"
  }

  assert {
    condition     = aws_iam_role.quarantine_warmup[0].permissions_boundary == var.permissions_boundary_arn
    error_message = "Warmup must retain the deployment permissions boundary."
  }
  assert {
    condition     = jsondecode(aws_iam_role.quarantine_warmup[0].assume_role_policy).Statement[0].Principal.Service == "lambda.amazonaws.com"
    error_message = "Only Lambda may assume the warmup role."
  }
  assert {
    condition = alltrue([
      for s in jsondecode(aws_iam_role_policy.quarantine_warmup[0].policy).Statement :
      s.Condition.StringEquals["lambda:VpcIds"] == var.quarantine_vpc_id &&
      s.Condition.StringEquals["aws:RequestTag/BraintrustQuarantine"] == "true"
      if s.Sid == "CreateQuarantine"
    ])
    error_message = "Warmup may only create tagged functions in the quarantine VPC."
  }
  assert {
    condition = alltrue([
      for s in jsondecode(aws_iam_role_policy.quarantine_warmup[0].policy).Statement :
      s.Resource == var.quarantine_function_role_arn && s.Condition.StringEquals["iam:PassedToService"] == "lambda.amazonaws.com"
      if s.Sid == "PassQuarantineRole"
    ])
    error_message = "Warmup may only pass the quarantine execution role to Lambda."
  }
  assert {
    condition = toset(flatten([
      for s in jsondecode(aws_iam_role_policy.quarantine_warmup[0].policy).Statement : flatten([s.Action])
      ])) == toset([
      "lambda:CreateFunction", "lambda:TagResource", "lambda:GetFunction", "iam:PassRole",
      "ec2:DescribeSecurityGroups", "ec2:DescribeSubnets", "ec2:DescribeVpcs"
    ])
    error_message = "Warmup must not inherit API, S3, or Lambda update/delete permissions."
  }
}

run "warmup_role_is_disabled_with_quarantine" {
  command = plan
  module {
    source = "./modules/services"
  }
  variables {
    use_quarantine_vpc = false
  }
  assert {
    condition = (
      length(aws_iam_role.quarantine_warmup) == 0 &&
      length(aws_iam_role_policy.quarantine_warmup) == 0 &&
      length(aws_iam_role_policy_attachment.quarantine_warmup_vpc_access) == 0 &&
      length(aws_lambda_function.quarantine_warmup) == 0
    )
    error_message = "Warmup IAM resources must share the function's quarantine gate."
  }
}
