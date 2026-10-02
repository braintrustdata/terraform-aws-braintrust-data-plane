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

run "lambda_api_version" {
  command = plan
  variables {
    enable_ecs_api = false
  }

  assert {
    condition     = local.brainstore_deployment_version == "test-lambda-version"
    error_message = "The helper must follow the Lambda API version while Lambda serves API traffic."
  }
}

run "ecs_api_version" {
  command = plan
  variables {
    enable_ecs_api = true
  }

  assert {
    condition     = local.brainstore_deployment_version == "test-ecs-version"
    error_message = "The helper must follow the ECS API version after ECS traffic cutover, even when the Lambda version differs."
  }
}
