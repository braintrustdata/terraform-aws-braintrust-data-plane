# Plan-mode smoke test for alternate PostgreSQL endpoint and credentials.
#
# The credentials secret is expected to contain JSON username/password fields.

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
    host                   = "database-alternate.example.internal"
    credentials_secret_arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:database-credentials-test"
  }
}

run "alternate_postgres_connection" {
  command = plan

  assert {
    condition     = local.postgres_host == "database-alternate.example.internal"
    error_message = "the alternate PostgreSQL host should be selected"
  }

  assert {
    condition     = local.postgres_credentials_secret_arn == var.postgres_connection_override.credentials_secret_arn
    error_message = "the alternate PostgreSQL credentials secret should be selected"
  }

  assert {
    condition     = length(aws_secretsmanager_secret.database_url_override) == 1
    error_message = "an effective URL secret should be created when host or credentials are overridden"
  }

  assert {
    condition     = aws_secretsmanager_secret.database_url_override[0].tags["BraintrustDeploymentName"] == var.deployment_name
    error_message = "the generated URL secret should carry the deployment-name tag"
  }

}

run "host_only_override" {
  command = plan

  variables {
    postgres_connection_override = {
      host = "database-proxy.example.internal"
    }
  }

  assert {
    condition     = local.postgres_host == "database-proxy.example.internal"
    error_message = "the host-only override should retain module-managed credentials"
  }

  assert {
    condition     = length(aws_secretsmanager_secret.database_url_override) == 1
    error_message = "the host-only override should create an effective URL secret"
  }
}

run "credentials_only_override" {
  command = plan

  variables {
    postgres_connection_override = {
      credentials_secret_arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:database-credentials-next"
    }
  }

  assert {
    condition     = local.postgres_credentials_secret_arn == var.postgres_connection_override.credentials_secret_arn
    error_message = "the credentials-only override should select the supplied credentials secret"
  }
}

run "rejects_empty_override" {
  command = plan

  variables {
    postgres_connection_override = {}
  }

  expect_failures = [var.postgres_connection_override]
}
