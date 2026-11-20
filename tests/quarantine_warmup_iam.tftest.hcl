# The warmup role creates quarantine functions at runtime, so its policy must
# stay scoped to tagged functions in the quarantine VPC. iam_consumers.tftest.hcl
# checks that the warmup function runs as this role.
mock_provider "aws" {
  source = "./tests/mocks/aws"
}

variables {
  region            = "us-east-1"
  account_id        = "123456789012"
  deployment_name   = "bt-test"
  create_ai_gateway = false

  permissions_boundary_arn = "arn:aws:iam::123456789012:policy/boundary"
  enable_quarantine_vpc    = true

  created_resources = {
    kms_key_arn                       = "arn:aws:kms:us-east-1:123456789012:key/00000000-0000-0000-0000-000000000000"
    database_secret_arn               = "arn:aws:secretsmanager:us-east-1:123456789012:secret:bt-test-database"
    database_url_secret_arn           = "arn:aws:secretsmanager:us-east-1:123456789012:secret:bt-test-database-url"
    function_tools_secret_arn         = "arn:aws:secretsmanager:us-east-1:123456789012:secret:function-tools"
    redis_url_secret_arn              = "arn:aws:secretsmanager:us-east-1:123456789012:secret:redis"
    brainstore_license_key_secret_arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:license"
    brainstore_s3_bucket_arn          = "arn:aws:s3:::bt-test-brainstore"
    code_bundle_s3_bucket_arn         = "arn:aws:s3:::bt-test-code-bundles"
    lambda_responses_s3_bucket_arn    = "arn:aws:s3:::bt-test-lambda-responses"
    quarantine_vpc_id                 = "vpc-87654321"
  }

  brainstore_deployment_log_group_arn = "arn:aws:logs:us-east-1:123456789012:log-group:/braintrust/bt-test/bt-test-BrainstoreDeployment"
  brainstore_asg_names                = ["bt-test-brainstore-reader-123"]
}

run "warmup_permissions_are_scoped" {
  command = plan
  module { source = "./modules/iam" }

  # The policy names this role's ARN, which a plan can't know yet.
  override_resource {
    target          = aws_iam_role.quarantine_function[0]
    override_during = plan
    values          = { arn = "arn:aws:iam::123456789012:role/bt-test-QuarantineFunctionRole" }
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
      s.Condition.StringEquals["lambda:VpcIds"] == var.created_resources.quarantine_vpc_id &&
      s.Condition.StringEquals["aws:RequestTag/BraintrustQuarantine"] == "true"
      if s.Sid == "AllowCreateQuarantineFunctions"
    ])
    error_message = "Warmup may only create tagged functions in the quarantine VPC."
  }
  assert {
    condition = alltrue([
      for s in jsondecode(aws_iam_role_policy.quarantine_warmup[0].policy).Statement :
      s.Resource == aws_iam_role.quarantine_function[0].arn && s.Condition.StringEquals["iam:PassedToService"] == "lambda.amazonaws.com"
      if s.Sid == "AllowPassQuarantineFunctionRole"
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

run "warmup_role_uses_a_caller_provided_quarantine_vpc" {
  command = plan
  module { source = "./modules/iam" }

  override_resource {
    target          = aws_iam_role.quarantine_function[0]
    override_during = plan
    values          = { arn = "arn:aws:iam::123456789012:role/bt-test-QuarantineFunctionRole" }
  }

  variables {
    existing_quarantine_vpc_id = "vpc-11111111"
    created_resources = merge(var.created_resources, {
      quarantine_vpc_id = null
    })
  }

  assert {
    condition = alltrue([
      for s in jsondecode(aws_iam_role_policy.quarantine_warmup[0].policy).Statement :
      s.Condition.StringEquals["lambda:VpcIds"] == "vpc-11111111"
      if s.Sid == "AllowCreateQuarantineFunctions"
    ])
    error_message = "A caller-provided quarantine VPC must scope warmup and replace the one the root module created."
  }
}

run "warmup_role_is_disabled_with_quarantine" {
  command = plan
  module { source = "./modules/iam" }

  variables {
    enable_quarantine_vpc = false
  }

  assert {
    condition = (
      length(aws_iam_role.quarantine_warmup) == 0 &&
      length(aws_iam_role_policy.quarantine_warmup) == 0 &&
      length(aws_iam_role_policy_attachment.quarantine_warmup_vpc_access) == 0
    )
    error_message = "Warmup IAM resources must share the function's quarantine gate."
  }
}

run "warmup_role_is_absent_on_external_eks" {
  command = plan
  module { source = "./modules/iam" }

  variables {
    use_deployment_mode_external_eks = true
    enable_eks_pod_identity          = true
  }

  assert {
    condition     = length(aws_iam_role.quarantine_warmup) == 0 && length(aws_iam_role.quarantine_function) == 1
    error_message = "External EKS has no warmup function, but it keeps the quarantine function role."
  }
}
