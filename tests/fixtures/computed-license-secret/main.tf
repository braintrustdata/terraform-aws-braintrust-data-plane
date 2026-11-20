resource "aws_kms_key" "license" {}

resource "aws_secretsmanager_secret" "license" {
  name       = "caller-license"
  kms_key_id = aws_kms_key.license.arn
}

resource "aws_secretsmanager_secret_version" "license" {
  secret_id     = aws_secretsmanager_secret.license.arn
  secret_string = "test-license"
}

module "dataplane" {
  source = "../../.."

  deployment_name     = "bt-test"
  braintrust_org_name = "test-org"
  primary_org_name    = "test-org"
  enable_loop_runtime = true
  existing_brainstore_license_key_secret = {
    arn         = aws_secretsmanager_secret_version.license.secret_id
    kms_key_arn = aws_kms_key.license.arn
  }
}
