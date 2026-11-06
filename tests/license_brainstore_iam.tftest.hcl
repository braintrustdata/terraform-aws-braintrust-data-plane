mock_provider "aws" {
  source = "./tests/mocks/aws"
  mock_resource "aws_iam_policy" {
    defaults = { arn = "arn:aws:iam::123456789012:policy/test" }
  }
}
variables {
  deployment_name                = "bt-test"
  vpc_id                         = "vpc-12345678"
  kms_key_arn                    = "arn:aws:kms:us-east-1:123456789012:key/00000000-0000-0000-0000-000000000000"
  brainstore_s3_bucket_arn       = "arn:aws:s3:::bt-test-brainstore"
  database_secret_arn            = "arn:aws:secretsmanager:us-east-1:123456789012:secret:bt-test-database"
  code_bundle_s3_bucket_arn      = "arn:aws:s3:::bt-test-code-bundles"
  lambda_responses_s3_bucket_arn = "arn:aws:s3:::bt-test-lambda-responses"
  enable_quarantine_vpc          = false

  brainstore_license_key_secret_arn  = "arn:aws:secretsmanager:us-east-1:123456789012:secret:license"
  brainstore_license_key_kms_key_arn = "arn:aws:kms:us-east-1:123456789012:key/license"
}
run "brainstore_can_read_external_license" {
  # The mock provider creates no AWS resources.
  command = apply
  module { source = "./modules/services-common" }
  override_resource {
    target = aws_secretsmanager_secret.function_tools_secret
    values = { arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:function-tools" }
  }
  assert {
    condition     = contains(jsondecode(aws_iam_role_policy.brainstore_secrets_access.policy).Statement[0].Resource, var.brainstore_license_key_secret_arn)
    error_message = "Brainstore must receive access to the existing license secret."
  }
  assert {
    condition     = one([for statement in jsondecode(aws_iam_role_policy.brainstore_secrets_access.policy).Statement : statement if statement.Action == "kms:Decrypt"]).Resource == var.brainstore_license_key_kms_key_arn && one([for statement in jsondecode(aws_iam_role_policy.brainstore_secrets_access.policy).Statement : statement if statement.Action == "kms:Decrypt"]).Condition.StringEquals["kms:ViaService"] == "secretsmanager.us-east-1.amazonaws.com"
    error_message = "The external key grant must allow only decryption through Secrets Manager."
  }
}
