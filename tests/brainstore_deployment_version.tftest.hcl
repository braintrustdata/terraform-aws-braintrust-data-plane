mock_provider "aws" {
  source = "./tests/mocks/aws"
}

mock_provider "random" {}

mock_provider "http" {
  source = "./tests/mocks/http"
}

variables {
  braintrust_org_name             = "test-org"
  primary_org_name                = "test-org"
  deployment_name                 = "bt-test"
  brainstore_license_key          = "test-license"
  lambda_version_tag_override     = "test-lambda-version"
  braintrust_api_version_override = "test-ecs-version"
}

run "ecs_api_version" {
  command = plan

  assert {
    condition     = local.api_version_tag == "test-ecs-version"
    error_message = "The helper must follow the ECS API version, even when the Lambda version differs."
  }
}
