# The partner tag is on by default and cannot be replaced or reintroduced
# through custom_tags. Opting out removes it from the shared tag map.

mock_provider "aws" {
  source = "./tests/mocks/aws"
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
  postgres_connection_override = {
    host = "database-alternate.example.internal"
  }
  custom_tags = {
    env          = "test"
    "aws-apn-id" = "pc:caller-supplied"
  }
}

run "partner_tag_wins_over_custom_tags" {
  command = plan

  assert {
    condition     = local.all_custom_tags["aws-apn-id"] == "pc:8ebp76p17b7i08cjqrxaoj0y8"
    error_message = "a caller-supplied aws-apn-id must not replace the module partner identifier"
  }

  assert {
    condition     = local.all_custom_tags["env"] == "test"
    error_message = "other custom tags should still be applied"
  }

  assert {
    condition     = aws_secretsmanager_secret.database_url_override[0].tags["aws-apn-id"] == "pc:8ebp76p17b7i08cjqrxaoj0y8"
    error_message = "created resources should receive the module partner identifier"
  }
}

run "partner_tag_can_be_omitted" {
  command = plan

  variables {
    enable_apn_partner_tag = false
  }

  assert {
    condition     = !contains(keys(local.all_custom_tags), "aws-apn-id")
    error_message = "disabling the partner tag should omit aws-apn-id even when custom_tags sets it"
  }

  assert {
    condition     = local.all_custom_tags["env"] == "test"
    error_message = "other custom tags should still be applied when the partner tag is disabled"
  }

  assert {
    condition     = !contains(keys(aws_secretsmanager_secret.database_url_override[0].tags), "aws-apn-id")
    error_message = "created resources should not receive aws-apn-id when the partner tag is disabled"
  }

  assert {
    condition     = aws_secretsmanager_secret.database_url_override[0].tags["env"] == "test"
    error_message = "created resources should still receive other custom tags"
  }
}
