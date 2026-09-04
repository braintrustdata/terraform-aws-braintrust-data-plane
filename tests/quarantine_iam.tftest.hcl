# Verify the quarantine function role keeps Lambda's managed VPC permissions
# while denying the same EC2 actions to code running inside the function.

mock_provider "aws" {
  source = "./tests/mocks/aws"
}

variables {
  deployment_name                = "bt-test"
  vpc_id                         = "vpc-12345678"
  kms_key_arn                    = "arn:aws:kms:us-east-1:123456789012:key/00000000-0000-0000-0000-000000000000"
  brainstore_s3_bucket_arn       = "arn:aws:s3:::bt-test-brainstore"
  database_secret_arn            = "arn:aws:secretsmanager:us-east-1:123456789012:secret:bt-test-database"
  code_bundle_s3_bucket_arn      = "arn:aws:s3:::bt-test-code-bundles"
  lambda_responses_s3_bucket_arn = "arn:aws:s3:::bt-test-lambda-responses"
  enable_quarantine_vpc          = true
  quarantine_vpc_id              = "vpc-87654321"
}

run "quarantine_function_role_is_hardened" {
  command = plan

  module {
    source = "./modules/services-common"
  }

  assert {
    condition     = length(aws_iam_role_policy.quarantine_function_deny_ec2) == 1
    error_message = "quarantine should attach the EC2 deny policy to the function role"
  }

  assert {
    condition     = aws_iam_role_policy.quarantine_function_deny_ec2[0].name == "DenyEC2FromFunctionCode"
    error_message = "quarantine should use the CloudFormation inline policy name"
  }

  assert {
    condition = (
      jsondecode(aws_iam_role_policy.quarantine_function_deny_ec2[0].policy).Version == "2012-10-17" &&
      jsondecode(aws_iam_role_policy.quarantine_function_deny_ec2[0].policy).Statement[0].Effect == "Deny" &&
      jsondecode(aws_iam_role_policy.quarantine_function_deny_ec2[0].policy).Statement[0].Resource == "*" &&
      jsondecode(aws_iam_role_policy.quarantine_function_deny_ec2[0].policy).Statement[0].Condition.ArnLike["lambda:SourceFunctionArn"] == "arn:aws:lambda:*:*:function:*" &&
      toset(jsondecode(aws_iam_role_policy.quarantine_function_deny_ec2[0].policy).Statement[0].Action) == toset([
        "ec2:CreateNetworkInterface",
        "ec2:DescribeNetworkInterfaces",
        "ec2:DescribeSubnets",
        "ec2:DeleteNetworkInterface",
        "ec2:DetachNetworkInterface",
        "ec2:AssignPrivateIpAddresses",
        "ec2:UnassignPrivateIpAddresses"
      ])
    )
    error_message = "quarantine EC2 deny policy should match the CloudFormation policy"
  }

  assert {
    condition     = aws_iam_role_policy_attachment.quarantine_function_role[0].policy_arn == "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
    error_message = "quarantine should retain AWSLambdaVPCAccessExecutionRole"
  }
}

run "quarantine_function_role_is_disabled_with_quarantine" {
  command = plan

  module {
    source = "./modules/services-common"
  }

  variables {
    enable_quarantine_vpc = false
    quarantine_vpc_id     = null
  }

  assert {
    condition = (
      length(aws_iam_role.quarantine_function_role) == 0 &&
      length(aws_iam_role_policy.quarantine_function_deny_ec2) == 0 &&
      length(aws_iam_role_policy_attachment.quarantine_function_role) == 0
    )
    error_message = "quarantine function IAM resources should share the quarantine count gate"
  }
}
