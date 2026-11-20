mock_provider "aws" {
  source = "./tests/mocks/aws"
  mock_data "aws_partition" { defaults = { partition = "aws", dns_suffix = "amazonaws.com" } }
  mock_data "aws_secretsmanager_secret_versions" {
    defaults = {
      versions = [
        { version_id = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee", version_stages = ["AWSCURRENT"] },
        { version_id = "ffffffff-bbbb-cccc-dddd-eeeeeeeeeeee", version_stages = ["AWSPREVIOUS"] },
      ]
    }
  }
}
mock_provider "random" {}
mock_provider "http" {
  source = "./tests/mocks/http"
}
variables {
  deployment_name     = "bt-test"
  braintrust_org_name = "test-org"
  primary_org_name    = "test-org"
}
run "managed_license" {
  command = plan
  variables { brainstore_license_key = "test-license" }
  assert {
    condition     = length(aws_secretsmanager_secret.brainstore_license_key) == 1 && length(aws_secretsmanager_secret_version.brainstore_license_key) == 1 && length(data.aws_secretsmanager_secret_versions.brainstore_license_key) == 0
    error_message = "A supplied license value must create one managed secret and version."
  }
}
run "existing_license_with_loop" {
  command = plan
  variables {
    existing_brainstore_license_key_secret = { arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:existing-license", kms_key_arn = "arn:aws:kms:us-east-1:123456789012:key/license" }
    enable_loop_runtime                    = true
  }
  assert {
    condition     = length(aws_secretsmanager_secret.brainstore_license_key) == 0 && length(aws_secretsmanager_secret_version.brainstore_license_key) == 0 && local.brainstore_license_key_secret_arn == var.existing_brainstore_license_key_secret.arn && local.brainstore_license_key_secret_version == "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
    error_message = "An existing secret must supply its current version without a managed copy."
  }
}
run "existing_license_takes_precedence" {
  command = plan
  variables {
    brainstore_license_key                 = "ignored-license"
    existing_brainstore_license_key_secret = { arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:existing-license" }
  }
  assert {
    condition     = !local.create_brainstore_license_secret && local.brainstore_license_key_secret_arn == var.existing_brainstore_license_key_secret.arn
    error_message = "An existing secret must take precedence over a supplied license value."
  }
}
run "external_eks_without_license" {
  command = plan
  variables { use_deployment_mode_external_eks = true }
  assert {
    condition     = length(aws_secretsmanager_secret.brainstore_license_key) == 0 && length(data.aws_secretsmanager_secret_versions.brainstore_license_key) == 0
    error_message = "External EKS must require no license and create no license secret."
  }
}
run "missing_license_rejected" {
  command         = plan
  expect_failures = [var.brainstore_license_key]
}
run "whitespace_license_rejected" {
  command = plan
  variables { brainstore_license_key = "   " }
  expect_failures = [var.brainstore_license_key]
}
run "invalid_secret_arn_rejected" {
  command = plan
  variables {
    existing_brainstore_license_key_secret = { arn = "not-a-secret-arn" }
  }
  expect_failures = [var.existing_brainstore_license_key_secret]
}

run "existing_rotation_uses_new_current_version" {
  command = plan
  variables {
    existing_brainstore_license_key_secret = { arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:existing-license" }
  }
  override_data {
    target = data.aws_secretsmanager_secret_versions.brainstore_license_key[0]
    values = {
      versions = [
        { version_id = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee", version_stages = ["AWSPREVIOUS"] },
        { version_id = "ffffffff-bbbb-cccc-dddd-eeeeeeeeeeee", version_stages = ["AWSCURRENT"] },
      ]
    }
  }
  assert {
    condition     = local.brainstore_license_key_secret_version == "ffffffff-bbbb-cccc-dddd-eeeeeeeeeeee"
    error_message = "A rotation must select the new current version for every consumer."
  }
}

run "empty_license_rejected" {
  command = plan
  variables { brainstore_license_key = "" }
  expect_failures = [var.brainstore_license_key]
}

run "empty_secret_rejected" {
  command = plan
  variables { existing_brainstore_license_key_secret = { arn = "" } }
  expect_failures = [var.existing_brainstore_license_key_secret]
}

run "whitespace_secret_rejected" {
  command = plan
  variables { existing_brainstore_license_key_secret = { arn = "   " } }
  expect_failures = [var.existing_brainstore_license_key_secret]
}
