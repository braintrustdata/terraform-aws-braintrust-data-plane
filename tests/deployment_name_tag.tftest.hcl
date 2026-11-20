# Plan-only tests: a caller tag can't change BraintrustDeploymentName. No AWS calls are made.

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
}

run "reserves_deployment_name_tag_over_custom_tags" {
  command = plan

  variables {
    custom_tags = {
      BraintrustDeploymentName = "another-deployment"
      team                     = "platform"
    }
  }

  assert {
    condition     = local.all_custom_tags["BraintrustDeploymentName"] == "bt-test" && local.all_custom_tags["team"] == "platform"
    error_message = "The module's deployment name must win over a caller's BraintrustDeploymentName, and other caller tags must remain."
  }

  assert {
    condition     = aws_secretsmanager_secret.brainstore_license_key[0].tags["BraintrustDeploymentName"] == "bt-test"
    error_message = "A resource that merges the deployment name before caller tags must still carry the module's deployment name."
  }
}

run "adds_deployment_name_tag_without_custom_tags" {
  command = plan

  assert {
    condition     = local.all_custom_tags == { "aws-apn-id" = "pc:8ebp76p17b7i08cjqrxaoj0y8", BraintrustDeploymentName = "bt-test" }
    error_message = "With no caller tags, the shared tags must be the partner tag and the deployment name."
  }
}
