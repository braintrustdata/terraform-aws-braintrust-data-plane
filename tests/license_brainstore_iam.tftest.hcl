mock_provider "aws" {
  source = "./tests/mocks/aws"
}

variables {
  region            = "us-east-1"
  account_id        = "123456789012"
  deployment_name   = "bt-test"
  create_ai_gateway = false

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
  }

  brainstore_deployment_log_group_arn = "arn:aws:logs:us-east-1:123456789012:log-group:/braintrust/bt-test/bt-test-BrainstoreDeployment"
  brainstore_asg_names                = ["bt-test-brainstore-reader-123"]

  existing_brainstore_license_key_secret = {
    arn         = "arn:aws:secretsmanager:us-east-1:123456789012:secret:existing-license"
    kms_key_arn = "arn:aws:kms:us-east-1:123456789012:key/license"
  }
}

run "brainstore_can_read_external_license" {
  command = plan
  module { source = "./modules/iam" }

  assert {
    condition     = contains(jsondecode(aws_iam_role_policy.brainstore_secrets_access[0].policy).Statement[0].Resource, var.existing_brainstore_license_key_secret.arn)
    error_message = "Brainstore must receive access to the existing license secret."
  }

  assert {
    condition     = !contains(jsondecode(aws_iam_role_policy.brainstore_secrets_access[0].policy).Statement[0].Resource, var.created_resources.brainstore_license_key_secret_arn)
    error_message = "A caller-supplied license secret must replace the one the root module created."
  }

  assert {
    condition     = one([for statement in jsondecode(aws_iam_role_policy.brainstore_secrets_access[0].policy).Statement : statement if statement.Action == "kms:Decrypt"]).Resource == var.existing_brainstore_license_key_secret.kms_key_arn && one([for statement in jsondecode(aws_iam_role_policy.brainstore_secrets_access[0].policy).Statement : statement if statement.Action == "kms:Decrypt"]).Condition.StringEquals["kms:ViaService"] == "secretsmanager.us-east-1.amazonaws.com"
    error_message = "The external key grant must allow only decryption through Secrets Manager."
  }
}

run "external_eks_brainstore_role_skips_ec2_only_secrets" {
  command = plan
  module { source = "./modules/iam" }

  variables {
    use_deployment_mode_external_eks = true
    custom_ca_bundle_secret_arn      = "arn:aws:secretsmanager:us-east-1:123456789012:secret:ca-bundle-AbCdEf"
    custom_ca_bundle_kms_key_arn     = "arn:aws:kms:us-east-1:123456789012:key/22222222-2222-2222-2222-222222222222"
  }

  assert {
    condition     = jsondecode(aws_iam_role_policy.brainstore_secrets_access[0].policy).Statement[0].Resource == [var.created_resources.database_secret_arn, var.created_resources.function_tools_secret_arn] && length(jsondecode(aws_iam_role_policy.brainstore_secrets_access[0].policy).Statement) == 1
    error_message = "External EKS has no license or CA bundle for Brainstore on EC2, so its role must read only the database and function tools secrets."
  }
}
