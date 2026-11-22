resource "aws_kms_key" "license" {}

resource "aws_secretsmanager_secret" "license" {
  name       = "caller-license"
  kms_key_id = aws_kms_key.license.arn
}

resource "aws_secretsmanager_secret_version" "license" {
  secret_id     = aws_secretsmanager_secret.license.arn
  secret_string = "test-license"
}

resource "aws_secretsmanager_secret" "keyrings" {
  for_each = toset(["function", "service-token"])
  name     = "caller-${each.key}-keys"
}

resource "aws_secretsmanager_secret_version" "keyrings" {
  for_each  = aws_secretsmanager_secret.keyrings
  secret_id = each.value.arn
  secret_string = jsonencode({
    active_key_name = "current"
    legacy_key_name = "legacy"
    keys = {
      current = { value = each.key }
      legacy  = { value = "legacy-key" }
    }
  })
}

module "dataplane" {
  source = "../../.."

  deployment_name     = "bt-test"
  braintrust_org_name = "test-org"
  primary_org_name    = "test-org"
  enable_loop_runtime = true

  function_secret_keys_secret_arn      = aws_secretsmanager_secret_version.keyrings["function"].secret_id
  service_token_secret_keys_secret_arn = aws_secretsmanager_secret_version.keyrings["service-token"].secret_id
  existing_brainstore_license_key_secret = {
    arn         = aws_secretsmanager_secret_version.license.secret_id
    kms_key_arn = aws_kms_key.license.arn
  }
}
